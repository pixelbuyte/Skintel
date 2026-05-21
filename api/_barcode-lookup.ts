import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

type LookupResult = {
  brand: string | null;
  productName: string | null;
  ingredients: string;
  source: 'openbeautyfacts' | 'openfoodfacts' | null;
};

async function fetchProduct(
  baseUrl: string,
  upc: string,
  timeoutMs = 5000
): Promise<{ brand: string | null; productName: string | null; ingredients: string } | null> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const r = await fetch(`${baseUrl}/api/v2/product/${encodeURIComponent(upc)}.json`, {
      signal: controller.signal,
      headers: { 'User-Agent': 'Skintel/1.0 (https://skintel.app)' },
    });
    if (!r.ok) return null;
    const data = (await r.json()) as {
      status?: number;
      product?: {
        product_name?: string;
        brands?: string;
        ingredients_text?: string;
      };
    };
    if (data.status !== 1 || !data.product) return null;
    const ingredients = (data.product.ingredients_text ?? '').trim();
    const brand = (data.product.brands ?? '').trim() || null;
    const productName = (data.product.product_name ?? '').trim() || null;
    if (!ingredients && !brand && !productName) return null;
    return { brand, productName, ingredients };
  } catch {
    return null;
  } finally {
    clearTimeout(timer);
  }
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return json(res, { error: 'Method not allowed' }, 405);
  }

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

  let upcRaw: unknown;
  if (req.method === 'GET') {
    upcRaw = req.query?.upc;
  } else {
    const body = (typeof req.body === 'string' ? JSON.parse(req.body) : req.body) as
      | { upc?: unknown }
      | undefined;
    upcRaw = body?.upc;
  }
  const upc = typeof upcRaw === 'string' ? upcRaw.trim() : '';
  if (!/^\d{8,13}$/.test(upc)) {
    return json(res, { error: 'Invalid UPC (must be 8-13 digits)' }, 400);
  }

  const obf = await fetchProduct('https://world.openbeautyfacts.org', upc);
  if (obf) {
    const result: LookupResult = { ...obf, source: 'openbeautyfacts' };
    return json(res, result);
  }

  const off = await fetchProduct('https://world.openfoodfacts.org', upc);
  if (off) {
    const result: LookupResult = { ...off, source: 'openfoodfacts' };
    return json(res, result);
  }

  return json(res, { error: 'Not found in databases', upc }, 404);
}
