import Anthropic from '@anthropic-ai/sdk';
import * as cheerio from 'cheerio';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

const MODEL = 'claude-haiku-4-5-20251001';
const FETCH_TIMEOUT_MS = 10_000;
const MAX_BYTES = 1_000_000; // 1MB
const UA = 'Mozilla/5.0 (compatible; SkintelBot/1.0)';

type Extracted = { brand?: string; productName?: string; ingredients: string };

function isValidHttpUrl(raw: string): URL | null {
  try {
    const u = new URL(raw);
    if (u.protocol !== 'http:' && u.protocol !== 'https:') return null;
    return u;
  } catch {
    return null;
  }
}

async function fetchPage(url: string): Promise<string> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), FETCH_TIMEOUT_MS);
  try {
    const resp = await fetch(url, {
      method: 'GET',
      redirect: 'follow',
      signal: controller.signal,
      headers: {
        'user-agent': UA,
        accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      },
    });
    if (!resp.ok) throw new Error(`Fetch failed: ${resp.status}`);

    const reader = resp.body?.getReader();
    if (!reader) {
      const text = await resp.text();
      return text.slice(0, MAX_BYTES);
    }
    const chunks: Uint8Array[] = [];
    let total = 0;
    while (true) {
      const { value, done } = await reader.read();
      if (done) break;
      if (value) {
        chunks.push(value);
        total += value.byteLength;
        if (total >= MAX_BYTES) {
          try {
            await reader.cancel();
          } catch {
            /* ignore */
          }
          break;
        }
      }
    }
    const merged = new Uint8Array(Math.min(total, MAX_BYTES));
    let offset = 0;
    for (const c of chunks) {
      const take = Math.min(c.byteLength, merged.byteLength - offset);
      merged.set(c.subarray(0, take), offset);
      offset += take;
      if (offset >= merged.byteLength) break;
    }
    return new TextDecoder('utf-8', { fatal: false }).decode(merged);
  } finally {
    clearTimeout(timer);
  }
}

function normalizeWhitespace(s: string): string {
  return s.replace(/\s+/g, ' ').trim();
}

function looksLikeIngredients(text: string): boolean {
  if (!text) return false;
  const stripped = text.replace(/[\s\u00a0]+/g, ' ').trim();
  if (stripped.length < 20) return false;
  const commaCount = (stripped.match(/,/g) ?? []).length;
  return commaCount >= 4;
}

function cleanIngredientsString(raw: string): string {
  let s = normalizeWhitespace(raw);
  // Strip leading "Ingredients:" / "INCI:" labels
  s = s.replace(/^\s*(ingredients?|inci|full\s+ingredients?\s+list|composition)\s*[:\-–—]\s*/i, '');
  // Trim trailing period
  s = s.replace(/\.+\s*$/, '');
  return s.trim();
}

function extractFromHtml(html: string): Extracted {
  const $ = cheerio.load(html);

  // brand: try common meta tags, then site name
  const brand =
    $('meta[property="product:brand"]').attr('content')?.trim() ||
    $('meta[name="brand"]').attr('content')?.trim() ||
    $('meta[property="og:site_name"]').attr('content')?.trim() ||
    undefined;

  // product name: og:title / twitter:title / <title>
  const productName =
    $('meta[property="og:title"]').attr('content')?.trim() ||
    $('meta[name="twitter:title"]').attr('content')?.trim() ||
    $('h1').first().text().trim() ||
    $('title').first().text().trim() ||
    undefined;

  // ----- ingredients hunt -----
  let ingredients = '';

  // 1) JSON-LD: any object with "ingredients"
  $('script[type="application/ld+json"]').each((_i, el) => {
    if (ingredients) return;
    const raw = $(el).contents().text();
    if (!raw) return;
    try {
      const parsed = JSON.parse(raw);
      const stack: unknown[] = Array.isArray(parsed) ? [...parsed] : [parsed];
      while (stack.length) {
        const node = stack.shift();
        if (!node || typeof node !== 'object') continue;
        const obj = node as Record<string, unknown>;
        for (const key of Object.keys(obj)) {
          const v = obj[key];
          if (
            /ingredient/i.test(key) &&
            typeof v === 'string' &&
            looksLikeIngredients(v)
          ) {
            ingredients = v;
            return;
          }
          if (v && typeof v === 'object') stack.push(v);
        }
      }
    } catch {
      /* ignore */
    }
  });

  // 2) dt/dd or th/td pairs with "Ingredients" label
  if (!ingredients) {
    $('dt, th').each((_i, el) => {
      if (ingredients) return;
      const label = $(el).text().trim();
      if (!/^(ingredients|inci|full ingredients|composition)\b/i.test(label)) return;
      const pair = el.tagName?.toLowerCase() === 'dt' ? $(el).next('dd') : $(el).next('td');
      const txt = pair.text().trim();
      if (looksLikeIngredients(txt)) ingredients = txt;
    });
  }

  // 3) elements whose own text starts with "Ingredients:"
  if (!ingredients) {
    $('p, div, span, li').each((_i, el) => {
      if (ingredients) return;
      const txt = $(el).text();
      const m = txt.match(/(?:^|\n)\s*(?:ingredients?|inci)\s*[:\-–—]\s*([\s\S]+?)(?:\n{2,}|$)/i);
      if (m && looksLikeIngredients(m[1])) ingredients = m[1];
    });
  }

  // 4) Heading "Ingredients" followed by paragraph/list
  if (!ingredients) {
    $('h1, h2, h3, h4, h5, h6, strong, b').each((_i, el) => {
      if (ingredients) return;
      const label = $(el).text().trim();
      if (!/^(ingredients|inci|full ingredients?( list)?|composition)\b/i.test(label)) return;
      let node = $(el).next();
      let collected = '';
      for (let i = 0; i < 4 && node.length; i++) {
        const t = node.text().trim();
        if (t) collected += (collected ? ' ' : '') + t;
        if (looksLikeIngredients(collected)) break;
        node = node.next();
      }
      if (looksLikeIngredients(collected)) ingredients = collected;
    });
  }

  // 5) Global regex over visible text as last cheerio resort
  if (!ingredients) {
    const bodyText = $('body').text();
    const m = bodyText.match(
      /(?:ingredients?|inci)\s*[:\-–—]\s*([A-Za-z0-9 ,/().\-\[\]®©™&'+%:;\u00c0-\u024f]{40,3000})/i,
    );
    if (m && looksLikeIngredients(m[1])) ingredients = m[1];
  }

  return {
    brand,
    productName,
    ingredients: ingredients ? cleanIngredientsString(ingredients) : '',
  };
}

function ingredientTokenCount(s: string): number {
  if (!s) return 0;
  return s.split(',').map((t) => t.trim()).filter(Boolean).length;
}

function stripToText(html: string): string {
  const $ = cheerio.load(html);
  $('script, style, noscript, svg, iframe').remove();
  return normalizeWhitespace($('body').text() || $.root().text() || '');
}

async function aiExtract(html: string, fallbackBrand?: string, fallbackName?: string): Promise<Extracted> {
  const text = stripToText(html).slice(0, 8000);
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY! });
  const resp = await client.messages.create({
    model: MODEL,
    max_tokens: 2048,
    system:
      'Extract product name, brand, and full INCI ingredient list from this page text. Return strict JSON only: {brand, productName, ingredients: string} — ingredients comma-separated.',
    messages: [{ role: 'user', content: text }],
  });
  const out = resp.content
    .filter((b): b is Anthropic.TextBlock => b.type === 'text')
    .map((b) => b.text)
    .join('');
  const match = out.match(/\{[\s\S]*\}/);
  if (!match) throw new Error('AI returned no JSON');
  const parsed = JSON.parse(match[0]) as Partial<Extracted>;
  return {
    brand: (parsed.brand && String(parsed.brand).trim()) || fallbackBrand,
    productName: (parsed.productName && String(parsed.productName).trim()) || fallbackName,
    ingredients: cleanIngredientsString(String(parsed.ingredients ?? '')),
  };
}

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
    url?: string;
  };
  const rawUrl = (body?.url ?? '').trim();
  const parsedUrl = isValidHttpUrl(rawUrl);
  if (!parsedUrl) return json(res, { error: 'Invalid URL' }, 400);

  let html: string;
  try {
    html = await fetchPage(parsedUrl.toString());
  } catch (e: any) {
    return json(res, { error: 'Failed to fetch page', detail: String(e?.message ?? e) }, 502);
  }

  let extracted = extractFromHtml(html);

  if (ingredientTokenCount(extracted.ingredients) < 5) {
    try {
      const ai = await aiExtract(html, extracted.brand, extracted.productName);
      if (ingredientTokenCount(ai.ingredients) >= ingredientTokenCount(extracted.ingredients)) {
        extracted = ai;
      }
    } catch (e: any) {
      if (!extracted.ingredients) {
        return json(
          res,
          { error: 'Could not extract ingredients', detail: String(e?.message ?? e) },
          422,
        );
      }
      // Else keep what cheerio found, even if short.
    }
  }

  if (!extracted.ingredients) {
    return json(res, { error: 'No ingredients found on page' }, 422);
  }

  return json(res, {
    brand: extracted.brand,
    productName: extracted.productName,
    ingredients: extracted.ingredients,
  });
}
