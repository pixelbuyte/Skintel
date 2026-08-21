import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import type { VercelRequest, VercelResponse } from '@vercel/node';

export function getServiceClient(): SupabaseClient {
  const url = process.env.VITE_SUPABASE_URL ?? process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key) throw new Error('Missing Supabase env');
  return createClient(url, key, { auth: { persistSession: false } });
}

export async function getUserFromAuthHeader(req: VercelRequest) {
  const auth = (req.headers.authorization ?? req.headers.Authorization ?? '') as string;
  const token = auth.startsWith('Bearer ') ? auth.slice(7) : null;
  if (!token) return null;
  const sb = getServiceClient();
  const { data, error } = await sb.auth.getUser(token);
  if (error || !data.user) return null;
  return data.user;
}

export function json(res: VercelResponse, body: unknown, status = 200) {
  res.status(status).setHeader('content-type', 'application/json');
  return res.send(JSON.stringify(body));
}

// Canonical production origin. Hardcoded (not env-driven) because VITE_APP_URL /
// APP_URL was found pointing at a stale Vercel deployment alias
// (https://skintel.vercel.app) while live -- every Stripe checkout success_url,
// cancel_url, and the billing portal return_url were sending real customers
// back to a domain that isn't the site. Production always uses this value
// regardless of what those env vars are set to, so a repeat of that
// misconfiguration can't leak into checkout again. Preview and local dev keep
// using the env vars (falling back to localhost) since they intentionally
// point elsewhere.
const PRODUCTION_APP_URL = 'https://www.skinstel.com';

export function appUrl() {
  if (process.env.VERCEL_ENV === 'production') return PRODUCTION_APP_URL;
  return process.env.VITE_APP_URL ?? process.env.APP_URL ?? 'http://localhost:5173';
}

export async function sendEmail({
  to,
  subject,
  html,
}: {
  to: string;
  subject: string;
  html: string;
}): Promise<void> {
  const key = process.env.RESEND_API_KEY;
  if (!key) return;
  await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: { Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' },
    body: JSON.stringify({
      from: 'Skintel <hello@skinstel.com>',
      to,
      subject,
      html,
    }),
  });
}

export async function readRawBody(req: VercelRequest): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}
