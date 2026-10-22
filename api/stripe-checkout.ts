import Stripe from 'stripe';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { appUrl, getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

// The founding offer lists at the full price ($49.99) and this promotion code
// discounts it to $20 -- applied server-side so nobody loses the deal by
// forgetting to type a code. Override via env if the code ever needs to
// rotate without a redeploy; the id here is a live Stripe object, not a secret.
const FOUNDING_PROMO_CODE_ID = process.env.STRIPE_PROMO_FOUNDING || 'promo_1U6I2NRrTdDFA54jRrHxFnMs';

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Website launch offer (no account needed): Skintel+ at $6.49/month for the first
 * three months, then $8.99/month. Two ways to pay:
 * - prepay: $19.47 today for three months (STRIPE_PRICE_LAUNCH_PREPAY, billed every
 *   3 months); the webhook schedules the switch to the $8.99 monthly price after it.
 * - monthly: the $8.99 monthly price (STRIPE_PRICE_LAUNCH_MONTHLY) with
 *   STRIPE_COUPON_LAUNCH_MONTHLY ($2.50 off for 3 months).
 * The launch prices are separate from VITE_STRIPE_PRICE_PRO ($9.00, the web Pricing page).
 * Stripe Checkout is opened with the email the buyer typed, which Stripe shows
 * read-only, so the webhook can attach Skintel+ to the account with that email.
 */
async function launchCheckout(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') return json(res, { error: 'Method not allowed' }, 405);
  let body: Record<string, unknown>;
  try {
    body = (typeof req.body === 'string' ? JSON.parse(req.body) : req.body) ?? {};
  } catch {
    return json(res, { error: 'Invalid JSON' }, 400);
  }
  const email = (typeof body.email === 'string' ? body.email : '').trim().toLowerCase();
  if (!EMAIL.test(email) || email.length > 200) return json(res, { error: 'Invalid email' }, 400);
  const plan = body.plan === 'monthly' ? 'monthly' : 'prepay';
  const ref = (typeof body.ref === 'string' ? body.ref : '').slice(0, 40);

  const monthlyPrice = process.env.STRIPE_PRICE_LAUNCH_MONTHLY;
  const prepayPrice = process.env.STRIPE_PRICE_LAUNCH_PREPAY;
  const coupon = process.env.STRIPE_COUPON_LAUNCH_MONTHLY;
  const priceId = plan === 'prepay' ? prepayPrice : monthlyPrice;
  if (!priceId || (plan === 'monthly' && !coupon)) return json(res, { error: 'Offer not configured' }, 500);

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
  const meta = { tier: 'pro', guest: 'true', launch: plan, ...(ref ? { ref } : {}) };
  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    customer_email: email,
    ...(plan === 'monthly' ? { discounts: [{ coupon: coupon! }] } : {}),
    metadata: meta,
    subscription_data: { metadata: meta },
    success_url: `${appUrl()}/checkout/success?offer=launch&session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${appUrl()}/#offer`,
  });
  if (!session.url) return json(res, { error: 'Checkout failed' }, 500);
  return json(res, { url: session.url });
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.query.offer === 'launch') return launchCheckout(req, res);
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
      discounts: [{ promotion_code: FOUNDING_PROMO_CODE_ID }],
      metadata: { tier: 'founding', guest: 'true', ...(ref ? { ref } : {}) },
      success_url: `${appUrl()}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
      cancel_url: `${appUrl()}/#offer`,
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
      ? { discounts: [{ promotion_code: FOUNDING_PROMO_CODE_ID }] }
      : { subscription_data: { metadata: { supabase_user_id: user.id, tier } } }),
    success_url: `${appUrl()}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${appUrl()}/pricing`,
  });

  return json(res, { url: session.url });
}
