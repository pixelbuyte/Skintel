import Stripe from 'stripe';
import { appUrl, getServiceClient, getUserFromAuthHeader, json } from './_lib';

export const config = { runtime: 'nodejs' };

export default async function handler(req: Request) {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, { status: 405 });

  const user = await getUserFromAuthHeader(req);
  if (!user) return json({ error: 'Unauthorized' }, { status: 401 });

  const { priceId, tier } = (await req.json()) as { priceId?: string; tier?: 'pro' | 'founding' };
  if (!priceId || !tier) return json({ error: 'Missing priceId or tier' }, { status: 400 });

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-12-18.acacia' as any });

  if (tier === 'founding') {
    const sb = getServiceClient();
    const { data } = await sb.rpc('founding_seats_remaining');
    if (typeof data === 'number' && data <= 0) {
      return json({ error: 'Founding seats sold out' }, { status: 409 });
    }
  }

  const sb = getServiceClient();
  const { data: sub } = await sb
    .from('subscriptions')
    .select('stripe_customer_id')
    .eq('user_id', user.id)
    .maybeSingle();

  const session = await stripe.checkout.sessions.create({
    mode: 'subscription',
    payment_method_types: ['card'],
    line_items: [{ price: priceId, quantity: 1 }],
    customer: sub?.stripe_customer_id ?? undefined,
    customer_email: sub?.stripe_customer_id ? undefined : user.email ?? undefined,
    client_reference_id: user.id,
    metadata: { supabase_user_id: user.id, tier },
    subscription_data: { metadata: { supabase_user_id: user.id, tier } },
    success_url: `${appUrl()}/checkout/success?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${appUrl()}/pricing`,
    allow_promotion_codes: true,
  });

  return json({ url: session.url });
}
