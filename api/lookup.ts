import type { VercelRequest, VercelResponse } from '@vercel/node';
import { json } from './_lib.js';
import productSearch from './_product-search.js';
import barcodeLookup from './_barcode-lookup.js';
import importUrl from './_import-url.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const mode = (req.query?.mode ?? '') as string;
  if (mode === 'search') return productSearch(req, res);
  if (mode === 'barcode') return barcodeLookup(req, res);
  if (mode === 'url') return importUrl(req, res);
  return json(res, { error: 'Invalid mode (use search|barcode|url)' }, 400);
}
