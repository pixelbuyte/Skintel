import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req: Request) {
  if (req.method !== 'GET') return json({ error: 'Method not allowed' }, { status: 405 });

  const user = await getUserFromAuthHeader(req);
  if (!user) return json({ error: 'Unauthorized' }, { status: 401 });

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

  return new Response(body, {
    headers: {
      'content-type': 'application/json',
      'content-disposition': `attachment; filename="skintel-export-${new Date().toISOString().slice(0, 10)}.json"`,
    },
  });
}
