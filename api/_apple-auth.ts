import { createHash, createPrivateKey, sign } from 'node:crypto';
import type { User } from '@supabase/supabase-js';

// Sign in with Apple credentials are separate from the App Store Connect / IAP key.
// This endpoint exchanges native iOS authorization codes, whose audience is the App ID.
const CLIENT_ID = 'com.skintel.app';
const APPLE_ORIGIN = 'https://appleid.apple.com';

export class AppleAccountDeletionError extends Error {
  constructor(message: string, readonly status: number) {
    super(message);
  }
}

const unavailable = () => new AppleAccountDeletionError(
  'Apple account deletion is temporarily unavailable. Your account has not been deleted.', 503,
);

/** Only server-verified identities/app_metadata decide whether Apple must be revoked. */
export function appleDeletionUserID(user: User): string | null {
  const identity = user.identities?.find((item) => item.provider === 'apple');
  if (identity) {
    const subject: unknown = identity.identity_data?.sub ?? identity.id;
    if (typeof subject !== 'string' || !subject) throw unavailable();
    return subject;
  }
  // An incomplete identity response must never let an Apple account skip revocation.
  if (user.app_metadata.provider === 'apple' ||
      (Array.isArray(user.app_metadata.providers) && user.app_metadata.providers.includes('apple'))) {
    throw unavailable();
  }
  return null;
}

function clientSecret(): string {
  const teamID = process.env.APPLE_SIGN_IN_TEAM_ID;
  const keyID = process.env.APPLE_SIGN_IN_KEY_ID;
  const privateKey = process.env.APPLE_SIGN_IN_PRIVATE_KEY;
  if (!teamID || !keyID || !privateKey) throw unavailable();
  try {
    const now = Math.floor(Date.now() / 1000);
    const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: keyID })).toString('base64url');
    const payload = Buffer.from(JSON.stringify({
      iss: teamID, iat: now, exp: now + 300, aud: APPLE_ORIGIN, sub: CLIENT_ID,
    })).toString('base64url');
    const key = createPrivateKey(privateKey.replace(/\\n/g, '\n'));
    if (key.asymmetricKeyType !== 'ec' || key.asymmetricKeyDetails?.namedCurve !== 'prime256v1') {
      throw unavailable();
    }
    const signature = sign('sha256', Buffer.from(`${header}.${payload}`), {
      key, dsaEncoding: 'ieee-p1363',
    }).toString('base64url');
    return `${header}.${payload}.${signature}`;
  } catch {
    // Never expose key material or a crypto/Apple response in a user-facing error or log.
    throw unavailable();
  }
}

export function assertAppleDeletionConfigured(): void {
  clientSecret();
}

async function appleRequest(path: 'token' | 'revoke', params: Record<string, string>): Promise<Response> {
  try {
    return await fetch(`${APPLE_ORIGIN}/auth/${path}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams(params),
      signal: AbortSignal.timeout(10_000),
      redirect: 'error',
    });
  } catch {
    throw unavailable();
  }
}

/** Obtain a fresh Apple token, bind it to this account, then revoke it before deletion. */
export async function revokeAppleForDeletion(user: User, code: unknown, nonce: unknown): Promise<void> {
  const subject = appleDeletionUserID(user);
  if (!subject) return;
  if (typeof code !== 'string' || !code || code.length > 4096 ||
      typeof nonce !== 'string' || nonce.length < 16 || nonce.length > 128) {
    throw new AppleAccountDeletionError(
      'Confirm with Apple in Skintel on your iPhone to disconnect Apple and delete your account.', 409,
    );
  }
  const secret = clientSecret();
  const response = await appleRequest('token', {
    client_id: CLIENT_ID, client_secret: secret, code, grant_type: 'authorization_code',
  });
  if (!response.ok) {
    if (response.status >= 500) throw unavailable();
    throw new AppleAccountDeletionError(
      'Apple confirmation expired or could not be verified. Confirm with Apple again. Your account has not been deleted.', 409,
    );
  }

  let token: unknown;
  let idToken: unknown;
  try {
    const data = await response.json();
    token = data.refresh_token;
    idToken = data.id_token;
  } catch {
    throw unavailable();
  }
  if (typeof token !== 'string' || !token || typeof idToken !== 'string') throw unavailable();

  // This ID token came directly from Apple's authenticated HTTPS token exchange, never
  // from the client. Match its subject/audience/nonce before revoking any authorization.
  let claims: Record<string, unknown>;
  try {
    const parts = idToken.split('.');
    if (parts.length !== 3) throw unavailable();
    claims = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (!claims || typeof claims !== 'object') throw unavailable();
  } catch {
    throw unavailable();
  }
  const expectedNonce = createHash('sha256').update(nonce).digest('hex');
  if (claims.iss !== APPLE_ORIGIN || claims.aud !== CLIENT_ID || claims.sub !== subject ||
      typeof claims.exp !== 'number' || claims.exp <= Date.now() / 1000 || claims.nonce !== expectedNonce) {
    throw new AppleAccountDeletionError(
      'Confirm with the Apple account you used for Skintel. Your account has not been deleted.', 409,
    );
  }

  const revoked = await appleRequest('revoke', {
    client_id: CLIENT_ID, client_secret: secret, token, token_type_hint: 'refresh_token',
  });
  // Apple returns 200 with an empty body, including for an already-invalidated token.
  if (revoked.status !== 200) throw unavailable();
}
