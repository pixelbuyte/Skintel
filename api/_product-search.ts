import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

type OBFProduct = {
  code?: string;
  product_name?: string;
  brands?: string;
  ingredients_text?: string;
  image_front_small_url?: string;
};

type OBFResponse = {
  products?: OBFProduct[];
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET') return json(res, { error: 'Method not allowed' }, 405);

  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);

  const sb = getServiceClient();
  const { data: subRow } = await sb
    .from('subscriptions')
    .select('tier, status')
    .eq('user_id', user.id)
    .maybeSingle();
  const active = subRow?.status === 'active' || subRow?.status === 'trialing';
  const isPro = active && (subRow?.tier === 'pro' || subRow?.tier === 'founding');
  if (!isPro) return json(res, { error: 'Pro required' }, 402);

  const q = (typeof req.query.q === 'string' ? req.query.q : '').trim();
  if (q.length < 2) return json(res, { error: 'Query must be at least 2 characters' }, 400);

  const url =
    'https://world.openbeautyfacts.org/api/v2/search' +
    '?categories_tags_en=cosmetics' +
    `&search_terms=${encodeURIComponent(q)}` +
    '&fields=code,product_name,brands,ingredients_text,image_front_small_url' +
    '&page_size=10';

  const controller = new AbortController();
  const timeoutId = setTimeout(() => controller.abort(), 5000);

  try {
    const resp = await fetch(url, {
      signal: controller.signal,
      headers: { 'user-agent': 'skintel/1.0 (+https://skintel.app)' },
    });
    clearTimeout(timeoutId);

    if (!resp.ok) {
      return json(res, { error: 'OpenBeautyFacts request failed', status: resp.status }, 502);
    }

    const data = (await resp.json()) as OBFResponse;
    const products = Array.isArray(data.products) ? data.products : [];

    const results = products
      .filter((p) => typeof p.ingredients_text === 'string' && p.ingredients_text.trim().length > 0)
      .map((p) => ({
        code: p.code ?? '',
        productName: p.product_name ?? '',
        brand: p.brands ?? '',
        ingredients: (p.ingredients_text ?? '').trim(),
        imageUrl: p.image_front_small_url ?? '',
      }));

    return json(res, { results });
  } catch (e: unknown) {
    clearTimeout(timeoutId);
    const msg = e instanceof Error ? e.message : String(e);
    const aborted = e instanceof Error && e.name === 'AbortError';
    return json(
      res,
      { error: aborted ? 'OpenBeautyFacts request timed out' : 'Product search failed', detail: msg },
      aborted ? 504 : 500
    );
  }
}
