import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, json, readRawBody } from './_lib.js';
import { applyAppleTransaction, verifyNotification, verifyTransaction } from './_apple.js';

export const config = { api: { bodyParser: false } };

/**
 * POST /api/apple-notifications — App Store Server Notifications V2.
 *
 * Register this URL in App Store Connect (App Information → App Store Server
 * Notifications, Production and Sandbox). Apple posts `{ signedPayload }`; we verify it,
 * pull the signed transaction inside, and re-apply it to the user's row. Renewals extend
 * `current_period_end`; expirations, refunds and revocations close the row. Idempotent via
 * `processed_webhook_events` (same table the Stripe webhook uses).
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);

  let signedPayload: string | undefined;
  try {
    const raw = await readRawBody(req);
    signedPayload = JSON.parse(raw)?.signedPayload;
  } catch {
    return json(res, { error: 'Invalid body' }, 400);
  }
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
