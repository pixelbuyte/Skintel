import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';
import { applyAppleTransaction, verifyTransaction } from './_apple.js';

/**
 * POST /api/apple-verify   { signedTransaction }
 *
 * The iOS app sends the StoreKit 2 signed transaction (JWS) after a purchase or restore.
 * We verify the signature chain against Apple's root CA, confirm the transaction belongs
 * to the signed-in user (appAccountToken == Supabase user id), and write the
 * `subscriptions` row — the same row Stripe writes, so one entitlement rule serves both.
 * Returns the row the app should display.
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);

  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);

  const body = (typeof req.body === 'string' ? safeParse(req.body) : req.body) ?? {};
  const signed = typeof body.signedTransaction === 'string' ? body.signedTransaction : null;
  if (!signed || signed.length > 20_000) return json(res, { error: 'signedTransaction required' }, 400);

  let tx;
  try {
    tx = await verifyTransaction(signed);
  } catch (err) {
    console.error('[apple-verify] verification failed', (err as Error).message);
    return json(res, { error: 'Transaction could not be verified' }, 422);
  }

  // Bind the purchase to this account. The app sets appAccountToken to the Supabase user
  // id; a transaction carrying a different token must not grant this user anything.
  if (tx.appAccountToken && tx.appAccountToken.toLowerCase() !== user.id.toLowerCase()) {
    return json(res, { error: 'Transaction belongs to a different account' }, 403);
  }

  try {
    const subscription = await applyAppleTransaction(getServiceClient(), user.id, tx);
    return json(res, { subscription });
  } catch (err) {
    console.error('[apple-verify] apply failed', (err as Error).message);
    return json(res, { error: 'Could not record subscription' }, 500);
  }
}

function safeParse(s: string): Record<string, unknown> | null {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
}
