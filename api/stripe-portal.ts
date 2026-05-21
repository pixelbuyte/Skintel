import Stripe from 'stripe';
import { appUrl, getServiceClient, getUserFromAuthHeader, json } from './_lib.js';

export const config = { runtime: 'nodejs' };

export default async function handler(req: Request) {
  if (req.method !== 'POST') return json({ error: 'Method not allowed' }, { status: 405 });

  const user = await getUserFromAuthHeader(req);
  if (!user) return json({ error: 'Unauthorized' }, { status: 401 });

  const sb = getServiceClient();
  const { data: sub } = await sb
    .from('subscriptions')
    .select('stripe_customer_id')
    .eq('user_id', user.id)
    .maybeSingle();

  if (!sub?.stripe_customer_id) {
    return json({ error: 'No billing account found' }, { status: 404 });
  }

  const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-12-18.acacia' as any });
  const session = await stripe.billingPortal.sessions.create({
    customer: sub.stripe_customer_id,
    return_url: `${appUrl()}/app/settings`,
  });

  return json({ url: session.url });
}
