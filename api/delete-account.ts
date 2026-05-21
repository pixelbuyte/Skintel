import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);

  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);

  const sb = getServiceClient();
  await sb.from('subscriptions').delete().eq('user_id', user.id);
  await sb.from('products').delete().eq('user_id', user.id);
  const { error } = await sb.auth.admin.deleteUser(user.id);
  if (error) return json(res, { error: error.message }, 500);

  return json(res, { ok: true });
}
