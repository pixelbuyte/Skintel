import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, json } from './_lib.js';

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const sb = getServiceClient();

  if (req.method === 'GET') {
    const { data, error } = await sb.rpc('founding_seats_remaining');
    res.setHeader('content-type', 'application/json');
    if (error) {
      res.status(500).send(JSON.stringify({ remaining: null, error: error.message }));
      return;
    }
    res.setHeader('cache-control', 'public, max-age=10, stale-while-revalidate=30');
    res.status(200).send(JSON.stringify({ remaining: data ?? 0 }));
    return;
  }

  if (req.method === 'POST') {
    const body = (typeof req.body === 'string' ? JSON.parse(req.body) : req.body) as {
      email?: string;
      source?: string;
    };
    const rawEmail = (body?.email ?? '').trim().toLowerCase();
    if (!rawEmail || rawEmail.length > 254 || !EMAIL_RE.test(rawEmail)) {
      return json(res, { error: 'Invalid email' }, 400);
    }
    const source = (body?.source ?? '').toString().slice(0, 64) || null;

    const { error } = await sb
      .from('waitlist')
      .insert({ email: rawEmail, source })
      .select()
      .maybeSingle();

    if (error && (error as any).code !== '23505') {
      return json(res, { error: 'Signup failed' }, 500);
    }

    return json(res, { ok: true });
  }

  return json(res, { error: 'Method not allowed' }, 405);
}
