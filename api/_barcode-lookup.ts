import type { VercelRequest, VercelResponse } from '@vercel/node';
import { complete, parseJsonObject, SCAN_MODELS } from './_ai.js';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

type CacheSource = 'openbeautyfacts' | 'openfoodfacts' | 'claude';

type LookupResult = {
  brand: string | null;
  productName: string | null;
  ingredients: string;
  source: CacheSource | 'cache' | null;
};

type CacheRow = {
  upc: string;
  brand: string | null;
  product_name: string | null;
  ingredients: string;
  source: string;
};

async function aiFillIngredients(
  brand: string | null,
  productName: string | null,
  upc: string
): Promise<{ brand: string | null; productName: string | null; ingredients: string } | null> {
  const hint = [brand, productName].filter(Boolean).join(' ');
  const prompt = `Find the full INCI ingredient list for this skincare/cosmetic product using web search: the brand's official page or major retailers (Sephora, Ulta, Boots).

Product: ${hint || '(unknown — look up by UPC)'}
UPC/EAN: ${upc}

Return strict JSON only — no commentary, no markdown:
{"brand": string|null, "productName": string|null, "ingredients": string}

- ingredients = full INCI, comma-separated, no "Ingredients:" prefix
- If you cannot find an authoritative list, return ingredients: ""
- Do NOT invent ingredients`;

  try {
    const ai = await complete({ models: SCAN_MODELS, prompt, maxTokens: 2048, json: true, webSearch: true });
    const parsed = parseJsonObject(ai.text) as {
      brand?: string | null;
      productName?: string | null;
      ingredients?: string;
    };
    return {
      brand: parsed.brand ?? brand ?? null,
      productName: parsed.productName ?? productName ?? null,
      ingredients: (parsed.ingredients ?? '').trim(),
    };
  } catch {
    return null;
  }
}

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

  // 1) Cache hit short-circuits everything (incl. AI web-search billing).
  const { data: cached } = await sb
    .from('barcode_cache')
    .select('upc, brand, product_name, ingredients, source')
    .eq('upc', upc)
    .maybeSingle<CacheRow>();
  if (cached && cached.ingredients) {
    const result: LookupResult = {
      brand: cached.brand,
      productName: cached.product_name,
      ingredients: cached.ingredients,
      source: 'cache',
    };
    return json(res, result);
  }

  const obf = await fetchProduct('https://world.openbeautyfacts.org', upc);
  const off = obf ? null : await fetchProduct('https://world.openfoodfacts.org', upc);
  const dbHit = obf ?? off;
  const dbSource: 'openbeautyfacts' | 'openfoodfacts' | null = obf
    ? 'openbeautyfacts'
    : off
    ? 'openfoodfacts'
    : null;

  async function persist(row: { brand: string | null; productName: string | null; ingredients: string; source: CacheSource }) {
    if (!row.ingredients) return;
    await sb
      .from('barcode_cache')
      .upsert(
        {
          upc,
          brand: row.brand,
          product_name: row.productName,
          ingredients: row.ingredients,
          source: row.source,
        },
        { onConflict: 'upc', ignoreDuplicates: true }
      );
  }

  if (dbHit && dbHit.ingredients && dbSource) {
    await persist({ ...dbHit, source: dbSource });
    const result: LookupResult = { ...dbHit, source: dbSource };
    return json(res, result);
  }

  const found = await aiFillIngredients(
    dbHit?.brand ?? null,
    dbHit?.productName ?? null,
    upc
  );

  if (found && (found.ingredients || found.brand || found.productName)) {
    const finalSource: CacheSource = dbSource ?? 'claude';
    if (found.ingredients) {
      await persist({
        brand: found.brand,
        productName: found.productName,
        ingredients: found.ingredients,
        source: finalSource,
      });
    }
    const result: LookupResult = {
      brand: found.brand,
      productName: found.productName,
      ingredients: found.ingredients,
      source: finalSource,
    };
    return json(res, result);
  }

  if (dbHit) {
    const result: LookupResult = { ...dbHit, source: dbSource };
    return json(res, result);
  }

  return json(res, { error: 'Not found in databases', upc }, 404);
}
