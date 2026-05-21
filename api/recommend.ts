import Anthropic from '@anthropic-ai/sdk';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

const MODEL = 'claude-haiku-4-5-20251001';

type Goal = 'cleanser' | 'moisturizer' | 'serum' | 'sunscreen' | 'toner' | 'exfoliant';
type Budget = 'drugstore' | 'mid' | 'luxury';

const GOALS: Goal[] = ['cleanser', 'moisturizer', 'serum', 'sunscreen', 'toner', 'exfoliant'];
const BUDGETS: Budget[] = ['drugstore', 'mid', 'luxury'];

const BUDGET_DESC: Record<Budget, string> = {
  drugstore: 'drugstore (under $20)',
  mid: 'mid ($20-50)',
  luxury: 'luxury ($50+)',
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
    goal?: string;
    budget?: string;
    notes?: string;
  };

  const goal = body?.goal as Goal | undefined;
  const budget = body?.budget as Budget | undefined;
  const notes = (body?.notes ?? '').trim().slice(0, 500);

  if (!goal || !GOALS.includes(goal)) return json(res, { error: 'Invalid goal' }, 400);
  if (!budget || !BUDGETS.includes(budget)) return json(res, { error: 'Invalid budget' }, 400);

  const { data: products } = await sb
    .from('products')
    .select('id, outcome, product_name, brand, product_ingredients(inci_normalized, inci_raw)')
    .eq('user_id', user.id);

  type Row = {
    id: string;
    outcome: 'good' | 'bad' | 'unsure' | null;
    product_name: string | null;
    brand: string | null;
    product_ingredients: { inci_normalized: string | null; inci_raw: string | null }[] | null;
  };

  const rows = (products ?? []) as Row[];

  const avoidCounts = new Map<string, { display: string; count: number }>();
  const preferCounts = new Map<string, { display: string; count: number }>();

  for (const p of rows) {
    const ings = p.product_ingredients ?? [];
    if (p.outcome === 'bad' || p.outcome === 'unsure') {
      for (const i of ings) {
        const key = (i.inci_normalized ?? '').trim();
        if (!key) continue;
        const display = (i.inci_raw ?? i.inci_normalized ?? '').trim();
        const cur = avoidCounts.get(key);
        if (cur) cur.count += 1;
        else avoidCounts.set(key, { display, count: 1 });
      }
    } else if (p.outcome === 'good') {
      for (const i of ings) {
        const key = (i.inci_normalized ?? '').trim();
        if (!key) continue;
        const display = (i.inci_raw ?? i.inci_normalized ?? '').trim();
        const cur = preferCounts.get(key);
        if (cur) cur.count += 1;
        else preferCounts.set(key, { display, count: 1 });
      }
    }
  }

  // Don't "prefer" ingredients that also show up frequently in bad/unsure products.
  for (const key of Array.from(preferCounts.keys())) {
    if (avoidCounts.has(key)) preferCounts.delete(key);
  }

  const topAvoid = Array.from(avoidCounts.values())
    .sort((a, b) => b.count - a.count)
    .slice(0, 40)
    .map((v) => v.display);

  const topPrefer = Array.from(preferCounts.values())
    .sort((a, b) => b.count - a.count)
    .slice(0, 25)
    .map((v) => v.display);

  const avoidStr = topAvoid.length > 0 ? topAvoid.join(', ') : '(none on record)';
  const preferStr = topPrefer.length > 0 ? topPrefer.join(', ') : '(none on record)';

  const system = `You are a skincare expert. Recommend 3 specific real products matching the user's category and budget. Avoid these ingredients: ${avoidStr}. Prefer products containing these (when relevant): ${preferStr}. Budget tiers: drugstore (under $20), mid ($20-50), luxury ($50+). Return ONLY strict JSON: {"recommendations": [{"brand": string, "productName": string, "category": string, "priceRange": string, "keyIngredients": string[], "whyItFits": string, "watchOuts": string|null}]}`;

  const userMsg = `Category: ${goal}
Budget: ${BUDGET_DESC[budget]}
${notes ? `User notes: ${notes}` : ''}

Return strict JSON only. Exactly 3 recommendations.`;

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

    return json(res, {
      result: parsed,
      meta: {
        avoidCount: topAvoid.length,
        preferCount: topPrefer.length,
      },
      usage: resp.usage,
    });
  } catch (e: any) {
    return json(res, { error: 'Recommendation failed', detail: String(e?.message ?? e) }, 500);
  }
}
