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

export function appUrl() {
  return process.env.VITE_APP_URL ?? process.env.APP_URL ?? 'http://localhost:5173';
}

export async function readRawBody(req: VercelRequest): Promise<string> {
  const chunks: Buffer[] = [];
  for await (const chunk of req) {
    chunks.push(typeof chunk === 'string' ? Buffer.from(chunk) : chunk);
  }
  return Buffer.concat(chunks).toString('utf8');
}
