import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json, readRawBody } from './_lib.js';
import { applyAppleTransaction, verifyNotification, verifyTransaction } from './_apple.js';

// Both actions need the raw body: the notification route is a webhook, and one function
// carries one bodyParser setting. We parse the JSON ourselves below.
export const config = { api: { bodyParser: false } };

/**
 * One function for both Apple endpoints — Vercel's Hobby plan caps a deployment at 12
 * serverless functions, so the public URLs are kept stable by rewrites in vercel.json:
 *
 *   POST /api/apple-verify          → /api/apple?action=verify
 *   POST /api/apple-notifications   → /api/apple?action=notifications
 *
 * The action is read from the query (same idiom as /api/journal?action=analyze). When it
 * is missing, the body shape decides: `{signedTransaction}` is a verify call from the app,
 * `{signedPayload}` is an App Store Server Notification.
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);

  let body: Record<string, unknown>;
  try {
    const raw = await readRawBody(req);
    if (raw.length > 64_000) return json(res, { error: 'Body too large' }, 413);
    body = raw ? JSON.parse(raw) : {};
    if (!body || typeof body !== 'object') return json(res, { error: 'Invalid body' }, 400);
  } catch {
    return json(res, { error: 'Invalid body' }, 400);
  }

  switch (actionFor(req, body)) {
    case 'verify':
      return verify(req, res, body);
    case 'notifications':
      return notifications(res, body);
    default:
      return json(res, { error: 'signedTransaction or signedPayload required' }, 400);
  }
}

function actionFor(req: VercelRequest, body: Record<string, unknown>): 'verify' | 'notifications' | null {
  const q = req.query?.action;
  const action = Array.isArray(q) ? q[0] : q;
  if (action === 'verify' || action === 'notifications') return action;
  if (typeof body.signedTransaction === 'string') return 'verify';
  if (typeof body.signedPayload === 'string') return 'notifications';
  return null;
}

/**
 * POST /api/apple-verify   { signedTransaction }
 *
 * The iOS app sends the StoreKit 2 signed transaction (JWS) after a purchase or restore.
 * We verify the signature chain against Apple's root CA, confirm the transaction belongs
 * to the signed-in user (appAccountToken == Supabase user id), and write the
 * `subscriptions` row — the same row Stripe writes, so one entitlement rule serves both.
 * Returns the row the app should display.
 */
async function verify(req: VercelRequest, res: VercelResponse, body: Record<string, unknown>) {
  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);

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

/**
 * POST /api/apple-notifications — App Store Server Notifications V2.
 *
 * Register this URL in App Store Connect (App Information → App Store Server
 * Notifications, Production and Sandbox). Apple posts `{ signedPayload }`; we verify it,
 * pull the signed transaction inside, and re-apply it to the user's row. Renewals extend
 * `current_period_end`; expirations, refunds and revocations close the row. Idempotent via
 * `processed_webhook_events` (same table the Stripe webhook uses).
 */
async function notifications(res: VercelResponse, body: Record<string, unknown>) {
  const signedPayload = body.signedPayload;
  if (typeof signedPayload !== 'string') return json(res, { error: 'signedPayload required' }, 400);

  let note;
  try {
    note = await verifyNotification(signedPayload);
  } catch (err) {
    console.error('[apple-notifications] verification failed', (err as Error).message);
    return json(res, { error: 'Unverified' }, 401);
  }

  const sb = getServiceClient();
  const eventId = note.notificationUUID ? `apple:${note.notificationUUID}` : null;
  if (eventId) {
    const { error } = await sb.from('processed_webhook_events').insert({ event_id: eventId });
    if (error) return json(res, { received: true, duplicate: true }); // unique violation → already handled
  }

  if (note.notificationType === 'TEST') return json(res, { received: true });

  const signedTx = note.data?.signedTransactionInfo;
  if (!signedTx) return json(res, { received: true });

  try {
    const tx = await verifyTransaction(signedTx);
    // Prefer the account token the app attached at purchase time; fall back to the row
    // that already holds this original transaction id.
    let userId = tx.appAccountToken ?? null;
    if (!userId && tx.originalTransactionId) {
      const { data } = await sb
        .from('subscriptions')
        .select('user_id')
        .eq('apple_original_transaction_id', tx.originalTransactionId)
        .maybeSingle();
      userId = data?.user_id ?? null;
    }
    if (!userId) {
      console.warn('[apple-notifications] no user for transaction', tx.originalTransactionId);
      return json(res, { received: true, unmatched: true });
    }
    await applyAppleTransaction(sb, userId, tx, note.notificationType ?? undefined);
    return json(res, { received: true });
  } catch (err) {
    console.error('[apple-notifications] apply failed', (err as Error).message);
    // 500 makes Apple retry with backoff, which is what we want for transient DB errors.
    return json(res, { error: 'Failed' }, 500);
  }
}
