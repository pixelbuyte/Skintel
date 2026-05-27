import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, json, sendEmail } from './_lib.js';

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

    const isNew = !error;
    if (isNew) {
      await sendEmail({
        to: rawEmail,
        subject: "You're on the Skintel list 🌿",
        html: `
          <div style="font-family:sans-serif;max-width:520px;margin:0 auto;color:#1a1a1a">
            <h2 style="font-size:24px;margin-bottom:8px">You're on the list.</h2>
            <p style="color:#555;line-height:1.6">
              We'll email you the moment Skintel hits the App Store and Google Play.
            </p>
            <p style="color:#555;line-height:1.6">
              While you wait — want 6 months of Pro access before the price goes up?
              Founding spots are limited to 500.
            </p>
            <a href="https://skinstel.com/pricing" style="display:inline-block;margin-top:16px;background:#A35848;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">
              Claim founding access — $20
            </a>
            <p style="margin-top:32px;color:#999;font-size:12px;">
              Skintel · skinstel.com<br>
              You signed up at skinstel.com. Reply to unsubscribe.
            </p>
          </div>
        `,
      });
    }

    return json(res, { ok: true });
  }

  return json(res, { error: 'Method not allowed' }, 405);
}
