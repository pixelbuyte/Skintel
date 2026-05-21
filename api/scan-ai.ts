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

  const system = `You are a dermatology-savvy skincare ingredient analyst. Analyze INCI lists for a user tracking breakout triggers.

Rules:
1. Produce ONE flag entry for EVERY token in the input ingredient list, in order — including water/glycerin/etc. Use level="low" for benign or beneficial ingredients (state benefit briefly), level="medium" for moderate-risk, level="high" for high-risk (comedogenic, sensitizing, irritating).
2. For non-ingredient tokens or obvious nonsense (e.g. "meth", "heluim", random letters, misspellings of common gases/metals/drugs) emit level="high" with reason="Not a valid INCI ingredient — likely typo, corruption, or tampering." and source="general".
3. Cross-reference user's personal correlation hits (provided below). When an ingredient matches both personal history AND general risk, source="both". Personal-only = "personal". General knowledge only = "general".
4. Reasons must be one factual sentence. No filler ("This may be" → "Is"). No marketing. No disclaimers in flags.
5. Comedogenic offenders to weight high: coconut oil, isopropyl myristate, isopropyl palmitate, myristyl myristate, lanolin, algae/seaweed extracts, cocoa butter, wheat germ oil, oleic-acid-heavy oils. Sensitizers: fragrance/parfum, linalool, limonene, citral, geraniol, MI/MCI, formaldehyde releasers (DMDM hydantoin, quaternium-15), denatured alcohol, essential oils. Surfactants harsh on acne-prone: SLS, sodium coco-sulfate.
6. Verdict rule: if any high-level flag → "avoid"; else if any medium → "caution"; else "clean".
7. Output strict JSON only. No prose, no markdown fences.

JSON schema:
{
  "verdict": "clean" | "caution" | "avoid",
  "summary": string (1-2 sentences naming the worst offender and overall character),
  "flags": [
    { "ingredient": string, "level": "high" | "medium" | "low", "reason": string, "source": "personal" | "general" | "both" }
  ],
  "notes": string (optional, 1 sentence with actionable advice)
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
      max_tokens: 4096,
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
