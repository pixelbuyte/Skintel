import Anthropic from '@anthropic-ai/sdk';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

const MODEL = 'claude-haiku-4-5-20251001';

type ProductRow = {
  id: string;
  brand: string | null;
  product_name: string;
  category: string | null;
};

type IngredientRow = {
  product_id: string;
  position: number;
  inci_raw: string;
  inci_normalized: string;
};

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);

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

  const body = (typeof req.body === 'string' ? JSON.parse(req.body) : req.body) as {
    amProductIds?: string[];
    pmProductIds?: string[];
  };
  const amIds = Array.isArray(body?.amProductIds) ? body.amProductIds.filter((x) => typeof x === 'string') : [];
  const pmIds = Array.isArray(body?.pmProductIds) ? body.pmProductIds.filter((x) => typeof x === 'string') : [];

  if (amIds.length === 0 && pmIds.length === 0) {
    return json(res, { error: 'Select at least one product' }, 400);
  }
  if (amIds.length > 20 || pmIds.length > 20) {
    return json(res, { error: 'Too many products per routine (max 20)' }, 400);
  }

  const allIds = Array.from(new Set([...amIds, ...pmIds]));

  const { data: productsData, error: pErr } = await sb
    .from('products')
    .select('id, brand, product_name, category')
    .eq('user_id', user.id)
    .in('id', allIds);
  if (pErr) return json(res, { error: 'Failed to fetch products', detail: pErr.message }, 500);

  const products = (productsData ?? []) as ProductRow[];
  if (products.length === 0) return json(res, { error: 'No matching products' }, 404);

  const validIds = new Set(products.map((p) => p.id));

  const { data: ingData, error: iErr } = await sb
    .from('product_ingredients')
    .select('product_id, position, inci_raw, inci_normalized')
    .eq('user_id', user.id)
    .in('product_id', Array.from(validIds));
  if (iErr) return json(res, { error: 'Failed to fetch ingredients', detail: iErr.message }, 500);

  const ingredients = (ingData ?? []) as IngredientRow[];
  const byProduct = new Map<string, IngredientRow[]>();
  for (const ing of ingredients) {
    if (!byProduct.has(ing.product_id)) byProduct.set(ing.product_id, []);
    byProduct.get(ing.product_id)!.push(ing);
  }
  for (const list of byProduct.values()) list.sort((a, b) => a.position - b.position);

  const productMap = new Map<string, ProductRow>();
  for (const p of products) productMap.set(p.id, p);

  function describeList(ids: string[]): string {
    const lines: string[] = [];
    let step = 1;
    for (const id of ids) {
      const p = productMap.get(id);
      if (!p) continue;
      const label = [p.brand, p.product_name].filter(Boolean).join(' ');
      const cat = p.category ? ` [${p.category}]` : '';
      const ings = (byProduct.get(id) ?? []).map((i) => i.inci_raw).join(', ') || '(no ingredients on file)';
      lines.push(`  ${step}. ${label}${cat}\n     INCI: ${ings}`);
      step++;
    }
    return lines.length > 0 ? lines.join('\n') : '  (empty)';
  }

  const amBlock = describeList(amIds);
  const pmBlock = describeList(pmIds);

  const system = `You are a dermatology-savvy routine reviewer. Analyze this AM and PM skincare routine for ingredient layering conflicts, redundancies, sensitization risks, and order-of-application issues. Return ONLY strict JSON: {"amVerdict": "good"|"caution"|"avoid", "pmVerdict": same, "conflicts": [{"products": string[], "issue": string, "severity": "high"|"medium"|"low", "fix": string}], "redundancies": string[], "suggestions": string[]}`;

  const userMsg = `AM ROUTINE (applied in order):
${amBlock}

PM ROUTINE (applied in order):
${pmBlock}

Analyze for: retinol + AHA/BHA + vitamin C overlap, fragrance accumulation, pH conflicts, comedogenic load, sensitization stacking, and order-of-application issues. Reference products by their brand + product name in conflict entries. Return strict JSON only. No prose, no markdown fences.`;

  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY! });

  try {
    const resp = await client.messages.create({
      model: MODEL,
      max_tokens: 2048,
      system,
      messages: [{ role: 'user', content: userMsg }],
    });

    const text = resp.content
      .filter((b): b is Anthropic.TextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('');

    let parsed: unknown;
    try {
      const match = text.match(/\{[\s\S]*\}/);
      parsed = JSON.parse(match ? match[0] : text);
    } catch {
      return json(res, { error: 'Model returned invalid JSON', raw: text.slice(0, 500) }, 502);
    }

    return json(res, { result: parsed, usage: resp.usage });
  } catch (e: any) {
    return json(res, { error: 'Routine analysis failed', detail: String(e?.message ?? e) }, 500);
  }
}
