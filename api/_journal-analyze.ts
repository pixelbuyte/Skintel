import Anthropic from '@anthropic-ai/sdk';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

const MODEL = 'claude-haiku-4-5-20251001';

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

  // 90-day cutoff
  const cutoff = new Date();
  cutoff.setDate(cutoff.getDate() - 90);
  const cutoffISO = cutoff.toISOString().slice(0, 10);

  const [journalRes, productsRes] = await Promise.all([
    sb
      .from('skin_journal')
      .select('entry_date, condition, notes')
      .eq('user_id', user.id)
      .gte('entry_date', cutoffISO)
      .order('entry_date', { ascending: true }),
    sb
      .from('products')
      .select('id, product_name, brand, outcome, created_at')
      .eq('user_id', user.id)
      .order('created_at', { ascending: true }),
  ]);

  if (journalRes.error) return json(res, { error: journalRes.error.message }, 500);
  if (productsRes.error) return json(res, { error: productsRes.error.message }, 500);

  const journal = journalRes.data ?? [];
  const products = productsRes.data ?? [];

  if (journal.length === 0) {
    return json(res, { error: 'No journal entries to analyze yet' }, 400);
  }

  const productIds = products.map((p) => p.id);
  let ingredientsByProduct = new Map<string, string[]>();
  if (productIds.length > 0) {
    const { data: ings } = await sb
      .from('product_ingredients')
      .select('product_id, inci_normalized, position')
      .in('product_id', productIds)
      .order('position', { ascending: true });
    for (const row of ings ?? []) {
      const arr = ingredientsByProduct.get(row.product_id) ?? [];
      arr.push(row.inci_normalized);
      ingredientsByProduct.set(row.product_id, arr);
    }
  }

  const journalLines = journal
    .map((j) => `${j.entry_date}: ${j.condition}${j.notes ? ` — ${j.notes.replace(/\s+/g, ' ').slice(0, 200)}` : ''}`)
    .join('\n');

  const productLines = products
    .map((p) => {
      const date = (p.created_at ?? '').slice(0, 10);
      const ings = (ingredientsByProduct.get(p.id) ?? []).slice(0, 20).join(', ');
      const label = [p.brand, p.product_name].filter(Boolean).join(' ');
      return `${date}: ADDED "${label}" [${p.outcome}]${ings ? ` — top ingredients: ${ings}` : ''}`;
    })
    .join('\n');

  const system = `You are analyzing a skincare journal. Given the user's skin condition log and product introduction timeline, identify likely culprit ingredients/products. Consider lag (breakouts often appear 3-14 days after a triggering product). Return ONLY strict JSON: {"summary": string, "suspects": [{"productOrIngredient": string, "confidence": "high"|"medium"|"low", "reasoning": string, "evidenceDates": string[]}], "patterns": string[], "recommendations": string[]}`;

  const userMsg = `SKIN CONDITION LOG (chronological, last 90 days):
${journalLines}

PRODUCT INTRODUCTION TIMELINE:
${productLines || '(no products logged)'}

Return strict JSON only. No prose, no markdown.`;

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
    return json(res, { error: 'AI analysis failed', detail: String(e?.message ?? e) }, 500);
  }
}
