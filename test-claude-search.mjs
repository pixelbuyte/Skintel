import 'dotenv/config';
import { readFileSync } from 'fs';
import Anthropic from '@anthropic-ai/sdk';

// load .env.production
const env = readFileSync('.env.production', 'utf8');
for (const line of env.split('\n')) {
  const m = line.match(/^([A-Z_]+)="?([^"\n]*)"?$/);
  if (m) process.env[m[1]] = m[2];
}

const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

async function fetchObf(upc) {
  const r = await fetch(`https://world.openbeautyfacts.org/api/v2/product/${upc}.json`, {
    headers: { 'User-Agent': 'Skintel/1.0' },
  });
  if (!r.ok) return null;
  const data = await r.json();
  if (data.status !== 1) return null;
  return {
    brand: data.product?.brands || null,
    productName: data.product?.product_name || null,
    ingredients: (data.product?.ingredients_text || '').trim(),
  };
}

async function claudeFill(brand, productName, upc) {
  const hint = [brand, productName].filter(Boolean).join(' ');
  const prompt = `Find the full INCI ingredient list for this skincare/cosmetic product. Use web_search to look up the brand's official page or major retailers (Sephora, Ulta, Boots, brand site).

Product: ${hint || '(unknown — look up by UPC)'}
UPC/EAN: ${upc}

Steps:
1. Search web for the product (use UPC and/or brand + product name).
2. Find the INCI / ingredients list from official brand site or reputable retailer.
3. Return strict JSON only — no commentary, no markdown.

Output format:
{"brand": string|null, "productName": string|null, "ingredients": string}

- ingredients = full INCI, comma-separated, no "Ingredients:" prefix
- If after searching you cannot find an authoritative list, return ingredients: ""
- Do NOT invent ingredients`;

  const resp = await client.messages.create({
    model: 'claude-haiku-4-5-20251001',
    max_tokens: 4096,
    tools: [{ type: 'web_search_20250305', name: 'web_search', max_uses: 4 }],
    messages: [{ role: 'user', content: prompt }],
  });
  console.log('Stop reason:', resp.stop_reason);
  console.log('Block types:', resp.content.map((b) => b.type));
  console.log('Server tool use:', resp.usage?.server_tool_use);
  const text = resp.content
    .filter((b) => b.type === 'text')
    .map((b) => b.text)
    .join('');
  console.log('Raw text len:', text.length);
  console.log('Raw text preview:', text.slice(0, 500));
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : (text.match(/\{[\s\S]*\}/)?.[0] ?? text);
  try {
    const parsed = JSON.parse(candidate);
    return parsed;
  } catch (e) {
    console.log('Parse failed:', e.message);
    return null;
  }
}

for (const upc of ['3337875597197', '0072140017769']) {
  console.log(`\n=== UPC ${upc} ===`);
  const obf = await fetchObf(upc);
  console.log('OBF:', obf ? { brand: obf.brand, productName: obf.productName, ingredientsLen: obf.ingredients.length } : null);
  if (obf?.ingredients) {
    console.log('OBF has ingredients — skipping Claude');
    continue;
  }
  console.log('Calling Claude+web_search...');
  const t0 = Date.now();
  const c = await claudeFill(obf?.brand ?? null, obf?.productName ?? null, upc);
  console.log('Claude took (s):', ((Date.now() - t0) / 1000).toFixed(1));
  console.log('Result:', c ? {
    brand: c.brand,
    productName: c.productName,
    ingredientsLen: (c.ingredients || '').length,
    sample: (c.ingredients || '').slice(0, 200),
  } : null);
}
