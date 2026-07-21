import Stripe from 'stripe';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { appUrl, getServiceClient, json } from './_lib.js';

// Guest checkout for the founding offer. No auth required — the buyer pays
// first, and the Stripe webhook creates (or matches) their account from the
// email Stripe collects. CTAs link here directly: GET → 303 to Stripe.
export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'GET' && req.method !== 'POST') {
    return json(res, { error: 'Method not allowed' }, 405);
  }

  const priceId = process.env.VITE_STRIPE_PRICE_FOUNDING;
  if (!priceId) return json(res, { error: 'Offer not configured' }, 500);

  const sb = getServiceClient();
  const { data: remaining } = await sb.rpc('founding_seats_remaining');
  if (typeof remaining === 'number' && remaining <= 0) {
    res.setHeader('location', `${appUrl()}/#founding`);
    res.status(303).end();
    return;
  }

  const ref = (typeof req.query.ref === 'string' ? req.query.ref : '').slice(0, 40);

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
    apiVersion: '2024-12-18.acacia' as any,
  });

  const session = await stripe.checkout.sessions.create({
    mode: 'payment',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    metadata: { tier: 'founding', guest: 'true', ...(ref ? { ref } : {}) },
    success_url: `${appUrl()}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${appUrl()}/#offer`,
    allow_promotion_codes: true,
  });

  if (!session.url) return json(res, { error: 'Checkout failed' }, 500);

  res.setHeader('location', session.url);
  res.status(303).end();
}
