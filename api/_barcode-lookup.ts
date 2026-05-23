import Anthropic from '@anthropic-ai/sdk';
import type { VercelRequest, VercelResponse } from '@vercel/node';
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

async function claudeFillIngredients(
  brand: string | null,
  productName: string | null,
  upc: string
): Promise<{ brand: string | null; productName: string | null; ingredients: string } | null> {
  if (!process.env.ANTHROPIC_API_KEY) return null;
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  const hint = [brand, productName].filter(Boolean).join(' ');
  const prompt = `Find the full INCI ingredient list for this skincare/cosmetic product. Use web_search to look up the brand's official page or major retailers (Sephora, Ulta, Boots, brand site).

Product: ${hint || '(unknown — look up by UPC)'}
UPC/EAN: ${upc}

Steps:
1. Search web for the product (use UPC and/or brand + product name).
2. Find the INCI / ingredients list from official brand site or reputable retailer.
3. Return strict JSON only — no commentary, no markdown.

Output format:
{"brand": string|null, "productName": string|null, "ingredients": string}

- ingredients = full INCI, comma-separated, no "Ingredients:" prefix
- If after searching you cannot find an authoritative list, return ingredients: ""
- Do NOT invent ingredients`;

  try {
    const resp = await client.messages.create({
      model: 'claude-haiku-4-5-20251001',
      max_tokens: 4096,
      tools: [
        {
          type: 'web_search_20250305',
          name: 'web_search',
          max_uses: 4,
        } as any,
      ],
      messages: [{ role: 'user', content: prompt }],
    });
    const text = resp.content
      .filter((b): b is Anthropic.TextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('');
    const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
    const candidate = fenced ? fenced[1] : (text.match(/\{[\s\S]*\}/)?.[0] ?? text);
    const parsed = JSON.parse(candidate) as {
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

  // 1) Cache hit short-circuits everything (incl. Claude web_search billing).
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

  const claude = await claudeFillIngredients(
    dbHit?.brand ?? null,
    dbHit?.productName ?? null,
    upc
  );

  if (claude && (claude.ingredients || claude.brand || claude.productName)) {
    const finalSource: CacheSource = dbSource ?? 'claude';
    if (claude.ingredients) {
      await persist({
        brand: claude.brand,
        productName: claude.productName,
        ingredients: claude.ingredients,
        source: finalSource,
      });
    }
    const result: LookupResult = {
      brand: claude.brand,
      productName: claude.productName,
      ingredients: claude.ingredients,
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
