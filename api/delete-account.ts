import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req: Request) {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, { status: 405 });

  const user = await getUserFromAuthHeader(req);
  if (!user) return json({ error: 'Unauthorized' }, { status: 401 });

  const sb = getServiceClient();
  await sb.from('subscriptions').delete().eq('user_id', user.id);
  await sb.from('products').delete().eq('user_id', user.id);
  const { error } = await sb.auth.admin.deleteUser(user.id);
  if (error) return json({ error: error.message }, { status: 500 });

  return json({ ok: true });
}
