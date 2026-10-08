import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';
import {
  AppleAccountDeletionError, appleDeletionUserID, assertAppleDeletionConfigured, revokeAppleForDeletion,
} from './_apple-auth.js';

/**
 * Account data rights in one function (Vercel Hobby allows 12 serverless functions per
 * deployment). Public URLs are unchanged — vercel.json rewrites them here:
 *
 *   GET  /api/export-data     → /api/account?action=export
 *   POST /api/delete-account  → /api/account?action=delete
 *
 * The action must be a single, explicit value: a request that somehow carries more than
 * one is rejected rather than guessed, because one of these deletes the account.
 */
export default async function handler(req: VercelRequest, res: VercelResponse) {
  const action = req.query?.action;
  if (Array.isArray(action)) return json(res, { error: 'Ambiguous action' }, 400);

  switch (action) {
    case 'export':
      if (req.method !== 'GET') return json(res, { error: 'Method not allowed' }, 405);
      return exportData(req, res);
    case 'delete':
      if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);
      return deleteAccount(req, res);
    case 'deletion-requirements':
      if (req.method !== 'GET') return json(res, { error: 'Method not allowed' }, 405);
      return deletionRequirements(req, res);
    default:
      return json(res, { error: 'Unknown action' }, 404);
  }
}

/** GET /api/export-data — everything we hold for the user, as a downloadable JSON file. */
async function exportData(req: VercelRequest, res: VercelResponse) {
  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);

  const sb = getServiceClient();
  const [{ data: products }, { data: subscription }] = await Promise.all([
    sb
      .from('products')
      .select('*, product_ingredients(*)')
      .eq('user_id', user.id)
      .order('created_at', { ascending: false }),
    sb.from('subscriptions').select('*').eq('user_id', user.id).maybeSingle(),
  ]);

  const body = JSON.stringify(
    {
      exported_at: new Date().toISOString(),
      user: { id: user.id, email: user.email },
      subscription,
      products,
    },
    null,
    2,
  );

  res.setHeader('content-type', 'application/json');
  res.setHeader(
    'content-disposition',
    `attachment; filename="skintel-export-${new Date().toISOString().slice(0, 10)}.json"`,
  );
  res.status(200).send(body);
}

/** GET /api/account?action=deletion-requirements — current server-verified Apple identity. */
async function deletionRequirements(req: VercelRequest, res: VercelResponse) {
  res.setHeader('Cache-Control', 'no-store');
  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);
  try {
    const appleUserID = appleDeletionUserID(user);
    if (appleUserID) assertAppleDeletionConfigured();
    return json(res, { appleUserID });
  } catch (error) {
    if (error instanceof AppleAccountDeletionError) return json(res, { error: error.message }, error.status);
    return json(res, { error: 'Unable to prepare account deletion. Try again.' }, 500);
  }
}

/** POST /api/delete-account — revoke Apple first, then atomically delete via auth FK cascades. */
async function deleteAccount(req: VercelRequest, res: VercelResponse) {
  res.setHeader('Cache-Control', 'no-store');
  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);

  try {
    await revokeAppleForDeletion(user, req.body?.appleAuthorizationCode, req.body?.appleNonce);
    // products, ingredients, skin_journal and subscriptions all reference auth.users
    // ON DELETE CASCADE. One hard delete avoids erasing rows before a later auth error.
    const { error } = await getServiceClient().auth.admin.deleteUser(user.id);
    if (error) return json(res, { error: 'Unable to delete your account. Try again.' }, 500);
    return json(res, { ok: true });
  } catch (error) {
    if (error instanceof AppleAccountDeletionError) return json(res, { error: error.message }, error.status);
    return json(res, { error: 'Unable to delete your account. Try again.' }, 500);
  }
}
