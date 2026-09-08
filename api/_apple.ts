import { Environment, SignedDataVerifier } from '@apple/app-store-server-library';
import type {
  JWSTransactionDecodedPayload,
  ResponseBodyV2DecodedPayload,
} from '@apple/app-store-server-library';
import type { SupabaseClient } from '@supabase/supabase-js';

/**
 * Apple In-App Purchase → `subscriptions` row.
 *
 * Verification uses Apple's Root CA G3 (embedded below; also at api/_apple/AppleRootCA-G3.cer)
 * so a forged JWS can never grant Pro. Both Production and Sandbox verifiers are tried,
 * because App Review and TestFlight purchase against Sandbox while the same build serves
 * real customers in Production.
 *
 * Required env: APPLE_APP_APPLE_ID (numeric App Store Connect id — Production verification
 * needs it). Optional: APPLE_BUNDLE_ID (default com.skintel.app), APPLE_ENVIRONMENT
 * ("Production" | "Sandbox" to restrict to one).
 */

const APPLE_ROOT_CA_G3_B64 =
  'MIICQzCCAcmgAwIBAgIILcX8iNLFS5UwCgYIKoZIzj0EAwMwZzEbMBkGA1UEAwwSQXBwbGUgUm9vdCBDQSAtIEczMSYwJAYDVQQLDB1BcHBsZSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eTETMBEGA1UECgwKQXBwbGUgSW5jLjELMAkGA1UEBhMCVVMwHhcNMTQwNDMwMTgxOTA2WhcNMzkwNDMwMTgxOTA2WjBnMRswGQYDVQQDDBJBcHBsZSBSb290IENBIC0gRzMxJjAkBgNVBAsMHUFwcGxlIENlcnRpZmljYXRpb24gQXV0aG9yaXR5MRMwEQYDVQQKDApBcHBsZSBJbmMuMQswCQYDVQQGEwJVUzB2MBAGByqGSM49AgEGBSuBBAAiA2IABJjpLz1AcqTtkyJygRMc3RCV8cWjTnHcFBbZDuWmBSp3ZHtfTjjTuxxEtX/1H7YyYl3J6YRbTzBPEVoA/VhYDKX1DyxNB0cTddqXl5dvMVztK517IDvYuVTZXpmkOlEKMaNCMEAwHQYDVR0OBBYEFLuw3qFYM4iapIqZ3r6966/ayySrMA8GA1UdEwEB/wQFMAMBAf8wDgYDVR0PAQH/BAQDAgEGMAoGCCqGSM49BAMDA2gAMGUCMQCD6cHEFl4aXTQY2e3v9GwOAEZLuN+yRhHFD/3meoyhpmvOwgPUnPWTxnS4at+qIxUCMG1mihDK1A3UT82NQz60imOlM27jbdoXt2QfyFMm+YhidDkLF1vLUagM6BgD56KyKA==';

/** Product ids created in App Store Connect (see IOS_SETUP.md). */
export const APPLE_PRODUCTS: Record<
  string,
  { tier: 'pro' | 'founding'; kind: 'auto-renewable' | 'non-renewing'; months?: number }
> = {
  'com.skintel.app.pro.monthly': { tier: 'pro', kind: 'auto-renewable' },
  'com.skintel.app.pro.yearly': { tier: 'pro', kind: 'auto-renewable' },
  'com.skintel.app.founding': { tier: 'founding', kind: 'non-renewing', months: 3 },
};

export type SubscriptionRow = {
  user_id: string;
  tier: 'free' | 'pro' | 'founding';
  status: string | null;
  current_period_end: string | null;
  founding_seat_number: number | null;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
  source: 'stripe' | 'apple' | 'grant' | null;
  apple_original_transaction_id: string | null;
  apple_product_id: string | null;
  created_at?: string;
  updated_at?: string;
};

let cached: SignedDataVerifier[] | null = null;

function verifiers(): SignedDataVerifier[] {
  if (cached) return cached;
  const root = Buffer.from(APPLE_ROOT_CA_G3_B64, 'base64');
  const bundleId = process.env.APPLE_BUNDLE_ID ?? 'com.skintel.app';
  const appAppleId = process.env.APPLE_APP_APPLE_ID ? Number(process.env.APPLE_APP_APPLE_ID) : undefined;
  const only = process.env.APPLE_ENVIRONMENT;
  const out: SignedDataVerifier[] = [];
  if (only !== 'Sandbox') {
    if (appAppleId) out.push(new SignedDataVerifier([root], true, Environment.PRODUCTION, bundleId, appAppleId));
    else console.warn('[apple] APPLE_APP_APPLE_ID unset — Production receipts cannot be verified');
  }
  if (only !== 'Production') out.push(new SignedDataVerifier([root], true, Environment.SANDBOX, bundleId, appAppleId));
  cached = out;
  return out;
}

async function firstThatVerifies<T>(fn: (v: SignedDataVerifier) => Promise<T>): Promise<T> {
  let last: unknown = new Error('No verifier configured');
  for (const v of verifiers()) {
    try {
      return await fn(v);
    } catch (err) {
      last = err;
    }
  }
  throw last instanceof Error ? last : new Error(String(last));
}

export function verifyTransaction(signed: string): Promise<JWSTransactionDecodedPayload> {
  return firstThatVerifies((v) => v.verifyAndDecodeTransaction(signed));
}

export function verifyNotification(signed: string): Promise<ResponseBodyV2DecodedPayload> {
  return firstThatVerifies((v) => v.verifyAndDecodeNotification(signed));
}

/**
 * Derive tier/status/period from a verified transaction and write the row.
 *
 * Reconciliation with Stripe: if the user already holds an *active* Stripe entitlement
 * that outlasts this Apple one, the Stripe values stay in charge (no double-grant, no
 * accidental downgrade); the Apple ids are still recorded so notifications can find the
 * row later.
 */
export async function applyAppleTransaction(
  sb: SupabaseClient,
  userId: string,
  tx: JWSTransactionDecodedPayload,
  notificationType?: string,
): Promise<SubscriptionRow> {
  const productId = tx.productId ?? '';
  const product = APPLE_PRODUCTS[productId];
  if (!product) throw new Error(`Unknown product ${productId}`);

  const now = Date.now();
  const purchasedAt = tx.purchaseDate ?? now;
  let periodEnd: number | null;
  if (product.kind === 'non-renewing') {
    const d = new Date(purchasedAt);
    d.setUTCMonth(d.getUTCMonth() + (product.months ?? 3));
    periodEnd = d.getTime();
  } else {
    periodEnd = tx.expiresDate ?? null;
  }

  let status: string;
  if (tx.revocationDate) {
    status = 'canceled';
    periodEnd = tx.revocationDate;
  } else if (notificationType === 'REFUND' || notificationType === 'REVOKE') {
    status = 'canceled';
    periodEnd = now;
  } else if (notificationType === 'DID_FAIL_TO_RENEW') {
    status = 'past_due';
  } else if (notificationType === 'EXPIRED' || notificationType === 'GRACE_PERIOD_EXPIRED') {
    status = 'expired';
  } else {
    status = periodEnd === null || periodEnd > now ? 'active' : 'expired';
  }

  const { data: existing } = await sb
    .from('subscriptions')
    .select('*')
    .eq('user_id', userId)
    .maybeSingle<SubscriptionRow>();

  const stripeActive =
    existing?.source === 'stripe' &&
    (existing.status === 'active' || existing.status === 'trialing') &&
    (existing.current_period_end === null ||
      new Date(existing.current_period_end).getTime() > (periodEnd ?? now));

  let seat = existing?.founding_seat_number ?? null;
  if (product.tier === 'founding' && seat === null && status === 'active') {
    const { data, error } = await sb.rpc('founding_next_seat');
    if (error) {
      // Sold out after the App Store already charged: honour the purchase, log the gap.
      console.warn('[apple] founding seat not allocated:', error.message);
    } else {
      seat = data as number;
    }
  }

  const row: SubscriptionRow = stripeActive
    ? {
        ...(existing as SubscriptionRow),
        apple_original_transaction_id: tx.originalTransactionId ?? existing?.apple_original_transaction_id ?? null,
        apple_product_id: productId,
      }
    : {
        user_id: userId,
        tier: status === 'active' || status === 'past_due' ? product.tier : 'free',
        status,
        current_period_end: periodEnd ? new Date(periodEnd).toISOString() : null,
        founding_seat_number: seat,
        stripe_customer_id: existing?.stripe_customer_id ?? null,
        stripe_subscription_id: existing?.stripe_subscription_id ?? null,
        source: 'apple',
        apple_original_transaction_id: tx.originalTransactionId ?? null,
        apple_product_id: productId,
      };

  const { data: saved, error } = await sb
    .from('subscriptions')
    .upsert(row, { onConflict: 'user_id' })
    .select('*')
    .single<SubscriptionRow>();
  if (error) throw new Error(error.message);
  return saved;
}
