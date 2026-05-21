import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') return json(res, { error: 'Method not allowed' }, 405);

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
