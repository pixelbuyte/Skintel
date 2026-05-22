import Anthropic from '@anthropic-ai/sdk';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

const MODEL = 'claude-haiku-4-5-20251001';

export const config = {
  api: {
    bodyParser: {
      sizeLimit: '8mb',
    },
  },
};

type AllowedMime = 'image/jpeg' | 'image/png' | 'image/webp';
const ALLOWED_MIME: AllowedMime[] = ['image/jpeg', 'image/png', 'image/webp'];

const PROMPT = `You are an OCR system for skincare product labels. Read the image carefully — text may be small, curved on a bottle, low contrast, or partially rotated.

Extract:
1. Brand name (usually largest text on front; "null" if not visible)
2. Product name (subtitle/descriptor; "null" if not visible)
3. Full INCI ingredient list — the comma-separated list usually starting with "Ingredients:" or "Composition:" or just a block of chemical names (Water, Glycerin, ...). Read EVERY ingredient even if list wraps lines. Preserve order and original spelling. Keep parenthetical CI codes.

Rules:
- If you see ANY ingredient-like words (e.g. Water, Aqua, Glycerin, ...), include them — do not return empty.
- If text is partially readable, transcribe what you can; do not invent.
- Join ingredients with ", " (comma + space). Do NOT add line breaks inside the string.
- Strip leading "Ingredients:" / "INCI:" / "Composition:" labels.

Return ONLY strict JSON, no markdown fences, no prose:
{"brand": string|null, "productName": string|null, "ingredients": string}

If genuinely nothing readable: {"brand": null, "productName": null, "ingredients": ""}`;

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
    imageBase64?: string;
    mimeType?: string;
  };

  const imageBase64 = (body?.imageBase64 ?? '').trim();
  const mimeType = body?.mimeType;

  if (!imageBase64) return json(res, { error: 'Missing imageBase64' }, 400);
  if (!mimeType || !ALLOWED_MIME.includes(mimeType as AllowedMime)) {
    return json(res, { error: 'Invalid mimeType. Use image/jpeg, image/png, or image/webp.' }, 400);
  }
  if (imageBase64.length > 6 * 1024 * 1024) {
    return json(res, { error: 'Image too large (base64 must be < 6MB)' }, 400);
  }

  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY! });

  try {
    const resp = await client.messages.create({
      model: MODEL,
      max_tokens: 2048,
      messages: [
        {
          role: 'user',
          content: [
            {
              type: 'image',
              source: {
                type: 'base64',
                media_type: mimeType as AllowedMime,
                data: imageBase64,
              },
            },
            { type: 'text', text: PROMPT },
          ],
        },
      ],
    });

    const text = resp.content
      .filter((b): b is Anthropic.TextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('');

    let parsed: unknown;
    try {
      const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
      const candidate = fenced ? fenced[1] : (text.match(/\{[\s\S]*\}/)?.[0] ?? text);
      parsed = JSON.parse(candidate);
    } catch {
      return json(res, { error: 'Model returned invalid JSON', raw: text.slice(0, 500) }, 502);
    }

    return json(res, { result: parsed, usage: resp.usage });
  } catch (e: any) {
    return json(res, { error: 'Photo scan failed', detail: String(e?.message ?? e) }, 500);
  }
}
