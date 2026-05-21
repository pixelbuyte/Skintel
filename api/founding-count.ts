import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient } from './_lib.js';

export default async function handler(_req: VercelRequest, res: VercelResponse) {
  const sb = getServiceClient();
  const { data, error } = await sb.rpc('founding_seats_remaining');
  res.setHeader('content-type', 'application/json');
  if (error) {
    res.status(500).send(JSON.stringify({ remaining: null, error: error.message }));
    return;
  }
  res.setHeader('cache-control', 'public, max-age=10, stale-while-revalidate=30');
  res.status(200).send(JSON.stringify({ remaining: data ?? 0 }));
}
