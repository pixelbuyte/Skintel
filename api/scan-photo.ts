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

const PROMPT = `You are a precise OCR system for skincare/cosmetic packaging. The image shows a product label (often the back of a bottle or jar). Transcribe everything you can see.

TASKS:
1. brand — the company/brand (e.g. "CeraVe", "The Ordinary", "Cetaphil", "La Roche-Posay"). Usually printed at top in bold/distinct typeface. If logo-only and unreadable, return null.
2. productName — the product descriptor (e.g. "Foaming Facial Cleanser", "Niacinamide 10% + Zinc 1%"). Typically below the brand. If absent return null.
3. ingredients — the FULL INCI list. Find any block labeled "Ingredients", "Ingrédients", "INCI", "Composition", "Active Ingredients", or an unlabeled comma-separated chemical list. Read every single token across all wrapped lines.

CRITICAL RULES:
- DO read the entire ingredient block. Don't stop at the first line. Most lists have 15-40 ingredients.
- DO preserve original spelling, accents, parentheses (e.g. "Tocopheryl Acetate", "CI 77891 (Titanium Dioxide)").
- DO join all ingredients into ONE string with ", " separator. Collapse line breaks into the separator.
- DO NOT invent ingredients you can't read. Skip illegible ones silently.
- DO NOT include the literal "Ingredients:" prefix in the output string.
- DO NOT add commentary, markdown fences, or prose.
- If the photo only shows the FRONT of the package and no ingredient list is visible, set ingredients to "" but still try to extract brand + productName from the front.

OUTPUT — strict JSON only:
{"brand": string|null, "productName": string|null, "ingredients": string}`;

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
      max_tokens: 4096,
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
