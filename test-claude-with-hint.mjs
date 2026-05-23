import { readFileSync } from 'fs';
import Anthropic from '@anthropic-ai/sdk';
const env = readFileSync('.env.production', 'utf8');
for (const line of env.split('\n')) {
  const m = line.match(/^([A-Z_]+)="?([^"\n]*)"?$/);
  if (m) process.env[m[1]] = m[2];
}
const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });

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
  console.log('Stop:', resp.stop_reason, '| searches:', resp.usage?.server_tool_use?.web_search_requests);
  const text = resp.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
  const fenced = text.match(/```(?:json)?\s*([\s\S]*?)```/);
  const candidate = fenced ? fenced[1] : (text.match(/\{[\s\S]*\}/)?.[0] ?? text);
  try { return JSON.parse(candidate); } catch { return { _raw: text.slice(0, 300) }; }
}

const cases = [
  { brand: 'CeraVe', productName: 'Hydrating Facial Cleanser', upc: '0301871239108' },
  { brand: 'The Ordinary', productName: 'Niacinamide 10% + Zinc 1%', upc: '0769915190618' },
  { brand: 'La Roche-Posay', productName: 'Anthelios Melt-in Milk SPF 60', upc: '3337875546324' },
];
for (const c of cases) {
  console.log(`\n=== ${c.brand} | ${c.productName} ===`);
  const t0 = Date.now();
  const r = await claudeFill(c.brand, c.productName, c.upc);
  console.log('Took (s):', ((Date.now()-t0)/1000).toFixed(1));
  console.log('Brand:', r?.brand, '| Product:', r?.productName);
  console.log('Ingredients len:', (r?.ingredients || '').length);
  console.log('Sample:', (r?.ingredients || '').slice(0, 300));
}
