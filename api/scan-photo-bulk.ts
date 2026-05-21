import Anthropic from '@anthropic-ai/sdk';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

const MODEL = 'claude-haiku-4-5-20251001';
const MAX_IMAGES = 5;
const MAX_TOTAL_BYTES = 15 * 1024 * 1024; // ~15MB across all images (under 16MB body limit)

export const config = { api: { bodyParser: { sizeLimit: '16mb' } } };

type ImageInput = { imageBase64: string; mimeType: string };

type AllowedMime = 'image/jpeg' | 'image/png' | 'image/gif' | 'image/webp';
const ALLOWED_MIMES: AllowedMime[] = ['image/jpeg', 'image/png', 'image/gif', 'image/webp'];

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
    images?: ImageInput[];
  };

  const images = Array.isArray(body?.images) ? body.images : [];
  if (images.length === 0) return json(res, { error: 'Missing images' }, 400);
  if (images.length > MAX_IMAGES) {
    return json(res, { error: `Max ${MAX_IMAGES} images per request` }, 400);
  }

  let totalBytes = 0;
  for (const img of images) {
    if (!img || typeof img.imageBase64 !== 'string' || typeof img.mimeType !== 'string') {
      return json(res, { error: 'Invalid image entry' }, 400);
    }
    if (!ALLOWED_MIMES.includes(img.mimeType as AllowedMime)) {
      return json(res, { error: `Unsupported mimeType: ${img.mimeType}` }, 400);
    }
    // approximate decoded byte size from base64 length
    totalBytes += Math.ceil((img.imageBase64.length * 3) / 4);
  }
  if (totalBytes > MAX_TOTAL_BYTES) {
    return json(res, { error: 'Total image payload too large' }, 413);
  }

  const instruction =
    'Each image shows skincare products. For EVERY product visible across all images, extract brand, product name, and full INCI ingredient list. Return ONLY strict JSON: {"products": [{"brand": string|null, "productName": string|null, "ingredients": string}]}. If a product\'s ingredient list is not visible, omit that product. Do not invent ingredients.';

  const content: Anthropic.ContentBlockParam[] = images.map((img) => ({
    type: 'image' as const,
    source: {
      type: 'base64' as const,
      media_type: img.mimeType as AllowedMime,
      data: img.imageBase64,
    },
  }));
  content.push({ type: 'text', text: instruction });

  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY! });

  try {
    const resp = await client.messages.create({
      model: MODEL,
      max_tokens: 4096,
      messages: [{ role: 'user', content }],
    });

    const text = resp.content
      .filter((b): b is Anthropic.TextBlock => b.type === 'text')
      .map((b) => b.text)
      .join('');

    let parsed: { products?: unknown } = {};
    try {
      const match = text.match(/\{[\s\S]*\}/);
      parsed = JSON.parse(match ? match[0] : text);
    } catch {
      return json(res, { error: 'Model returned invalid JSON', raw: text.slice(0, 500) }, 502);
    }

    const rawProducts = Array.isArray(parsed.products) ? parsed.products : [];
    const products = rawProducts
      .map((p) => p as { brand?: unknown; productName?: unknown; ingredients?: unknown })
      .filter((p) => typeof p.ingredients === 'string' && (p.ingredients as string).trim().length > 0)
      .map((p) => ({
        brand: typeof p.brand === 'string' ? p.brand : null,
        productName: typeof p.productName === 'string' ? p.productName : null,
        ingredients: (p.ingredients as string).trim(),
      }));

    return json(res, { products, usage: resp.usage });
  } catch (e: any) {
    return json(res, { error: 'AI bulk scan failed', detail: String(e?.message ?? e) }, 500);
  }
}
