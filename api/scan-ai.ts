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

  const body = (typeof req.body === 'string' ? JSON.parse(req.body) : req.body) as {
    inci?: string;
    matches?: { name: string; risk: 'high' | 'medium'; badCount: number }[];
  };
  const inci = (body?.inci ?? '').trim();
  if (!inci) return json(res, { error: 'Missing inci' }, 400);
  if (inci.length > 8000) return json(res, { error: 'Ingredient list too long' }, 400);

  const { data: products } = await sb
    .from('products')
    .select('outcome, product_name, brand')
    .eq('user_id', user.id);

  const counts = {
    good: products?.filter((p) => p.outcome === 'good').length ?? 0,
    bad: products?.filter((p) => p.outcome === 'bad').length ?? 0,
    unsure: products?.filter((p) => p.outcome === 'unsure').length ?? 0,
  };

  const personal = (body.matches ?? [])
    .map((m) => `- ${m.name} (${m.risk.toUpperCase()}, in ${m.badCount} of your bad products)`)
    .join('\n') || '- (none from your personal history)';

  const system = `You are a dermatology-savvy skincare ingredient analyst. You analyze INCI lists for a user who tracks which products cause breakouts.

You must:
1. Cite general acne/sensitivity risk factors: comedogenic ingredients (coconut oil, isopropyl myristate, lanolin, algae extracts, etc.), fragrance/parfum, essential oils, denatured alcohol, certain sulfates, common allergens (MI/MCI, formaldehyde releasers).
2. Cross-reference user's personal correlation hits with first-principles ingredient knowledge.
3. Be specific and brief. No marketing fluff. No medical disclaimers beyond one short line.
4. Output strict JSON only.

JSON schema:
{
  "verdict": "clean" | "caution" | "avoid",
  "summary": string (1-2 sentences),
  "flags": [
    { "ingredient": string, "level": "high" | "medium" | "low", "reason": string (1 sentence), "source": "personal" | "general" | "both" }
  ],
  "notes": string (optional, 1 sentence)
}`;

  const userMsg = `User stats: ${counts.good} good, ${counts.bad} bad, ${counts.unsure} unsure products.

Personal correlation hits in this INCI:
${personal}

Full INCI list to analyze:
${inci}

Return strict JSON only. No prose.`;

  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY! });

  try {
    const resp = await client.messages.create({
      model: MODEL,
      max_tokens: 1024,
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
    return json(res, { error: 'AI scan failed', detail: String(e?.message ?? e) }, 500);
  }
}
