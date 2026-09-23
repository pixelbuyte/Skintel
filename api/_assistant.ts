import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

/**
 * Ask Skintel: POST /api/assistant (rewritten to /api/recommend?action=assistant, because
 * the Hobby plan caps the project at 12 serverless functions).
 *
 * Body: { messages: [{ role: 'user' | 'assistant', content }], routine?: { am: string[], pm: string[] } }
 * Reply: { reply, model }
 *
 * The OpenRouter key lives only in Vercel env (OPENROUTER_API_KEY); the app never sees it.
 * Pro-only, like every other AI feature, which also keeps spend bounded to paying users.
 * 503 means the key isn't configured, and the app falls back to its preview reply.
 */

const DEFAULT_MODEL = 'anthropic/claude-haiku-4.5';
const MAX_MESSAGES = 12;
const MAX_MESSAGE_CHARS = 1500;
const MAX_REPLY_CHARS = 6000;

type ChatMessage = { role: 'user' | 'assistant'; content: string };

type ProductRow = {
  product_name: string | null;
  brand: string | null;
  category: string | null;
  outcome: 'good' | 'bad' | 'unsure' | null;
};

function clean(value: unknown, max: number): string {
  return typeof value === 'string' ? value.trim().slice(0, max) : '';
}

function cleanList(value: unknown, maxItems: number, maxChars: number): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .slice(0, maxItems)
    .map((v) => clean(v, maxChars))
    .filter((v) => v.length > 0);
}

export async function handleAssistant(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);

  const apiKey = process.env.OPENROUTER_API_KEY;
  if (!apiKey) return json(res, { error: 'Assistant not configured' }, 503);

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

  let body: Record<string, unknown>;
  try {
    body = (typeof req.body === 'string' ? JSON.parse(req.body) : req.body) ?? {};
  } catch {
    return json(res, { error: 'Invalid JSON' }, 400);
  }

  const rawMessages = Array.isArray(body.messages) ? body.messages : [];
  const messages: ChatMessage[] = rawMessages
    .slice(-MAX_MESSAGES)
    .map((m: unknown): ChatMessage => {
      const r = (m ?? {}) as { role?: unknown; content?: unknown };
      return { role: r.role === 'assistant' ? 'assistant' : 'user', content: clean(r.content, MAX_MESSAGE_CHARS) };
    })
    .filter((m) => m.content.length > 0);
  if (messages.length === 0 || messages[messages.length - 1].role !== 'user') {
    return json(res, { error: 'The last message must be a question.' }, 400);
  }

  const routine = (body.routine ?? {}) as { am?: unknown; pm?: unknown };
  const am = cleanList(routine.am, 12, 120);
  const pm = cleanList(routine.pm, 12, 120);

  const meta = (user.user_metadata ?? {}) as Record<string, unknown>;
  const skinType = typeof meta.skin_type === 'string' ? meta.skin_type : 'not set';
  const concerns = cleanList(meta.concerns, 8, 40);

  const { data: products } = await sb
    .from('products')
    .select('product_name, brand, category, outcome')
    .eq('user_id', user.id)
    .order('created_at', { ascending: false })
    .limit(40);
  const shelf =
    ((products ?? []) as ProductRow[])
      .map((p) => {
        const name = [p.brand, p.product_name].filter(Boolean).join(' ') || 'Unnamed product';
        const category = p.category ? ` (${p.category})` : '';
        const outcome = p.outcome === 'good' ? 'worked for them' : p.outcome === 'bad' ? 'broke them out' : 'unsure';
        return `- ${name}${category}: ${outcome}`;
      })
      .join('\n') || '(nothing on their shelf yet)';

  const system = `You are Skintel's skincare assistant inside the Skintel iOS app. You help one person with their own skincare routine, products and ingredients.

Rules:
- Be concise and practical: short paragraphs or a few bullets, under 180 words unless they ask for more.
- Use their skin profile, routine and shelf below whenever relevant, and name their actual products.
- You are not a doctor. Do not diagnose conditions or give prescription dosing. For severe, spreading, painful, blistering or persistent (more than a few days) reactions, or anything like an allergic reaction, tell them to see a dermatologist or doctor.
- Do not invent facts about specific products. Say when you're not sure.
- Plain text only. You may use **bold** and simple "1." or "•" lists. No headings, tables or links.

Skin profile: type ${skinType}; concerns: ${concerns.join(', ') || 'none set'}
Morning routine: ${am.join(' → ') || 'not set'}
Night routine: ${pm.join(' → ') || 'not set'}
Shelf, newest first:
${shelf}`;

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 25_000);
  try {
    const r = await fetch('https://openrouter.ai/api/v1/chat/completions', {
      method: 'POST',
      signal: controller.signal,
      headers: {
        Authorization: `Bearer ${apiKey}`,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://www.skinstel.com',
        'X-Title': 'Skintel',
      },
      body: JSON.stringify({
        model: process.env.OPENROUTER_MODEL || DEFAULT_MODEL,
        max_tokens: 600,
        temperature: 0.4,
        messages: [{ role: 'system', content: system }, ...messages],
      }),
    });
    const data = (await r.json().catch(() => null)) as
      | { model?: string; choices?: { message?: { content?: unknown } }[] }
      | null;
    if (!r.ok) {
      if (r.status === 429) return json(res, { error: 'Ask Skintel is busy. Try again in a moment.' }, 429);
      return json(res, { error: 'Ask Skintel is unavailable right now.' }, 502);
    }
    const reply = clean(data?.choices?.[0]?.message?.content, MAX_REPLY_CHARS);
    if (!reply) return json(res, { error: 'Ask Skintel returned an empty reply.' }, 502);
    return json(res, { reply, model: data?.model ?? null });
  } catch {
    return json(res, { error: 'Ask Skintel is unavailable right now.' }, 502);
  } finally {
    clearTimeout(timeout);
  }
}
