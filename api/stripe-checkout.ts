import Stripe from 'stripe';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { appUrl, getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

export default async function handler(req: VercelRequest, res: VercelResponse) {
  const isGuestFounding = req.query.offer === 'founding';

  // Guest founding checkout shares this endpoint so the Hobby deployment stays
  // within Vercel's function limit. Stripe collects the buyer's email and the
  // webhook creates (or matches) their account after payment.
  if (isGuestFounding) {
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
    return;
  }

  if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);

  const user = await getUserFromAuthHeader(req);
  if (!user) return json(res, { error: 'Unauthorized' }, 401);

  const body = (typeof req.body === 'string' ? JSON.parse(req.body) : req.body) as {
    priceId?: string;
    tier?: 'pro' | 'founding';
  };
  const { priceId, tier } = body ?? {};
  if (!priceId || !tier) return json(res, { error: 'Missing priceId or tier' }, 400);

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-12-18.acacia' as any });

  if (tier === 'founding') {
    const sb = getServiceClient();
    const { data } = await sb.rpc('founding_seats_remaining');
    if (typeof data === 'number' && data <= 0) {
      return json(res, { error: 'Founding seats sold out' }, 409);
    }
  }

  const sb = getServiceClient();
  const { data: sub } = await sb
    .from('subscriptions')
    .select('stripe_customer_id')
    .eq('user_id', user.id)
    .maybeSingle();

  const isFounding = tier === 'founding';
  const session = await stripe.checkout.sessions.create({
    mode: isFounding ? 'payment' : 'subscription',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    customer: sub?.stripe_customer_id ?? undefined,
    customer_email: sub?.stripe_customer_id ? undefined : user.email ?? undefined,
    client_reference_id: user.id,
    metadata: { supabase_user_id: user.id, tier },
    ...(isFounding
      ? {}
      : { subscription_data: { metadata: { supabase_user_id: user.id, tier } } }),
    success_url: `${appUrl()}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${appUrl()}/pricing`,
    allow_promotion_codes: true,
  });

  return json(res, { url: session.url });
}
