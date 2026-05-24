import Anthropic from '@anthropic-ai/sdk';
import * as cheerio from 'cheerio';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

const MODEL = 'claude-haiku-4-5-20251001';
const FETCH_TIMEOUT_MS = 15_000;
const MAX_BYTES = 3_000_000; // 3MB — Amazon/Sephora pages can be huge

// Real Chrome on Windows UA so retail sites don't return bot-block pages
const UA =
  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36';

const BROWSER_HEADERS: Record<string, string> = {
  'user-agent': UA,
  accept:
    'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
  'accept-language': 'en-US,en;q=0.9',
  'accept-encoding': 'gzip, deflate, br',
  'cache-control': 'no-cache',
  pragma: 'no-cache',
  'sec-ch-ua': '"Chromium";v="131", "Not_A Brand";v="24", "Google Chrome";v="131"',
  'sec-ch-ua-mobile': '?0',
  'sec-ch-ua-platform': '"Windows"',
  'sec-fetch-dest': 'document',
  'sec-fetch-mode': 'navigate',
  'sec-fetch-site': 'none',
  'sec-fetch-user': '?1',
  'upgrade-insecure-requests': '1',
};

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
      headers: BROWSER_HEADERS,
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
  s = s.replace(/^\s*(ingredients?|inci|full\s+ingredients?\s+list|composition)\s*[:\-–—]\s*/i, '');
  s = s.replace(/\.+\s*$/, '');
  return s.trim();
}

function detectBotBlock(html: string): string | null {
  const lc = html.toLowerCase();
  if (lc.includes('captcha-delivery.com') || lc.includes('px-captcha') || lc.includes('datadome')) {
    return 'Site bot protection (DataDome). Try a brand-direct URL instead.';
  }
  if (lc.includes('robot check') || lc.includes('/errors/validatecaptcha')) {
    return 'Amazon bot protection page returned. Try the brand product page or paste the ingredient list directly.';
  }
  if (lc.includes('access denied') && lc.includes('cloudfront')) {
    return 'Site blocked our fetch (Cloudfront). Try the brand product page or paste ingredients directly.';
  }
  if (lc.includes('akamai') && lc.includes('reference #')) {
    return 'Site blocked our fetch (Akamai). Try the brand product page or paste ingredients directly.';
  }
  return null;
}

// Site-specific extractors run BEFORE generic ones.
function extractAmazon($: cheerio.CheerioAPI): string {
  // Amazon shows ingredients in #important-information section (bullet-listed) or
  // an "Ingredients" labeled row inside #productDetails table.
  const labelRegex = /^(ingredients?|inci|full ingredients?( list)?)\b/i;

  // 1. #important-information has h4/h5 "Ingredients" + paragraph
  const importantSection = $('#important-information');
  if (importantSection.length) {
    let found = '';
    importantSection.find('h4, h5, .a-text-bold').each((_i, el) => {
      if (found) return;
      const label = $(el).text().trim();
      if (!labelRegex.test(label)) return;
      let node = $(el).parent().next();
      for (let i = 0; i < 5 && node.length; i++) {
        const txt = node.text().trim();
        if (looksLikeIngredients(txt)) {
          found = txt;
          return;
        }
        node = node.next();
      }
      // Also try sibling text inside same content block
      const sib = $(el).nextAll().slice(0, 5).text().trim();
      if (looksLikeIngredients(sib)) found = sib;
    });
    if (found) return found;
  }

  // 2. Look for "Ingredients" label inside any .content section
  let scanResult = '';
  $('.content, .a-section, #aplus, #aplus_feature_div').each((_i, el) => {
    if (scanResult) return;
    const html = $(el).html() ?? '';
    const m = html.match(
      /(?:<(?:h[1-6]|strong|b)[^>]*>\s*ingredients?\s*[:\-–—]?\s*<\/[^>]+>)([\s\S]{40,4000})/i,
    );
    if (m) {
      const piece = cheerio.load(m[1])('body').text();
      if (looksLikeIngredients(piece)) scanResult = piece;
    }
  });
  return scanResult;
}

function extractSephora($: cheerio.CheerioAPI): string {
  // Sephora puts ingredients inside .css-pz80c5 / dt-dd accordion / "Ingredients" h2 section
  let found = '';
  $('h2, h3, button[aria-controls]').each((_i, el) => {
    if (found) return;
    const label = $(el).text().trim();
    if (!/ingredient/i.test(label)) return;
    let node = $(el).parent();
    for (let i = 0; i < 4 && node.length; i++) {
      const txt = node.text().trim();
      // Pull the part AFTER the "Ingredients" word
      const idx = txt.toLowerCase().indexOf('ingredients');
      const sliced = idx >= 0 ? txt.slice(idx + 'ingredients'.length).replace(/^[\s:.\-–—]+/, '') : txt;
      if (looksLikeIngredients(sliced)) {
        found = sliced;
        return;
      }
      node = node.parent();
    }
  });
  return found;
}

function extractUlta($: cheerio.CheerioAPI): string {
  // Ulta accordion: <button>Ingredients</button> then <div>text</div>
  let found = '';
  $('button, summary, h3, h4').each((_i, el) => {
    if (found) return;
    if (!/^ingredients\b/i.test($(el).text().trim())) return;
    const parent = $(el).parent();
    const txt = parent.text();
    const idx = txt.toLowerCase().indexOf('ingredients');
    const sliced = idx >= 0 ? txt.slice(idx + 'ingredients'.length).replace(/^[\s:.\-–—]+/, '') : '';
    if (looksLikeIngredients(sliced)) found = sliced;
  });
  return found;
}

function extractFromHtml(html: string, url: URL): Extracted {
  const $ = cheerio.load(html);

  const host = url.hostname.toLowerCase();
  const isAmazon = /(^|\.)amazon\./.test(host);
  const isSephora = /(^|\.)sephora\./.test(host);
  const isUlta = /(^|\.)ulta\./.test(host);

  // brand
  const brand =
    $('meta[property="product:brand"]').attr('content')?.trim() ||
    $('meta[name="brand"]').attr('content')?.trim() ||
    $('#bylineInfo').text().trim().replace(/^(Brand|Visit the)\s*:?\s*/i, '').replace(/\s+Store$/i, '') ||
    $('[data-at="brand_name"]').text().trim() ||
    $('meta[property="og:site_name"]').attr('content')?.trim() ||
    undefined;

  // product name
  const productName =
    $('meta[property="og:title"]').attr('content')?.trim() ||
    $('meta[name="twitter:title"]').attr('content')?.trim() ||
    $('#productTitle').text().trim() ||
    $('[data-at="product_name"]').text().trim() ||
    $('h1').first().text().trim() ||
    $('title').first().text().trim() ||
    undefined;

  let ingredients = '';

  // site-specific FIRST
  if (isAmazon) ingredients = extractAmazon($);
  else if (isSephora) ingredients = extractSephora($);
  else if (isUlta) ingredients = extractUlta($);

  // 1) JSON-LD
  if (!ingredients) {
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
            if (/ingredient/i.test(key) && typeof v === 'string' && looksLikeIngredients(v)) {
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
  }

  // 2) dt/dd or th/td pairs
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

  // 3) elements whose text starts with "Ingredients:"
  if (!ingredients) {
    $('p, div, span, li').each((_i, el) => {
      if (ingredients) return;
      const txt = $(el).text();
      const m = txt.match(/(?:^|\n)\s*(?:ingredients?|inci)\s*[:\-–—]\s*([\s\S]+?)(?:\n{2,}|$)/i);
      if (m && looksLikeIngredients(m[1])) ingredients = m[1];
    });
  }

  // 4) Heading "Ingredients" followed by content
  if (!ingredients) {
    $('h1, h2, h3, h4, h5, h6, strong, b').each((_i, el) => {
      if (ingredients) return;
      const label = $(el).text().trim();
      if (!/^(ingredients|inci|full ingredients?( list)?|composition)\b/i.test(label)) return;
      let node = $(el).next();
      let collected = '';
      for (let i = 0; i < 6 && node.length; i++) {
        const t = node.text().trim();
        if (t) collected += (collected ? ' ' : '') + t;
        if (looksLikeIngredients(collected)) break;
        node = node.next();
      }
      if (looksLikeIngredients(collected)) ingredients = collected;
    });
  }

  // 5) Global regex over visible text
  if (!ingredients) {
    const bodyText = $('body').text();
    const m = bodyText.match(
      /(?:ingredients?|inci)\s*[:\-–—]\s*([A-Za-z0-9 ,/().\-\[\]®©™&'+%:;\u00c0-\u024f]{40,4000})/i,
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
  $('script, style, noscript, svg, iframe, header, footer, nav').remove();
  return normalizeWhitespace($('body').text() || $.root().text() || '');
}

async function aiExtract(
  html: string,
  url: URL,
  fallbackBrand?: string,
  fallbackName?: string,
): Promise<Extracted> {
  const text = stripToText(html).slice(0, 16000);
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY! });
  const resp = await client.messages.create({
    model: MODEL,
    max_tokens: 2048,
    system: `You are extracting product info from a beauty/skincare product page on ${url.hostname}.
Return strict JSON only — no preamble, no markdown fences:
{"brand": string, "productName": string, "ingredients": string}

Rules:
- ingredients = comma-separated INCI list (full list, not summary).
- If only a partial list is shown (e.g. "key ingredients"), return what you find.
- If no ingredients exist on the page, return empty string for ingredients.
- Strip "Ingredients:" / "INCI:" prefix.`,
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

  // Bot-block detection
  const blockReason = detectBotBlock(html);
  if (blockReason) {
    return json(res, { error: blockReason }, 422);
  }

  let extracted = extractFromHtml(html, parsedUrl);

  if (ingredientTokenCount(extracted.ingredients) < 5) {
    try {
      const ai = await aiExtract(html, parsedUrl, extracted.brand, extracted.productName);
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
    }
  }

  if (!extracted.ingredients) {
    return json(
      res,
      {
        error:
          'No ingredients found on that page. The site may hide them behind JavaScript. Try copy-pasting the ingredient list directly.',
      },
      422,
    );
  }

  return json(res, {
    brand: extracted.brand,
    productName: extracted.productName,
    ingredients: extracted.ingredients,
  });
}
