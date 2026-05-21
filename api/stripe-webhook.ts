import Stripe from 'stripe';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, readRawBody } from './_lib.js';

export const config = { api: { bodyParser: false } };

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-12-18.acacia' as any });

function tierFromPriceId(priceId: string | undefined | null): 'pro' | 'founding' | null {
  if (!priceId) return null;
  if (priceId === process.env.VITE_STRIPE_PRICE_FOUNDING) return 'founding';
  if (priceId === process.env.VITE_STRIPE_PRICE_PRO) return 'pro';
  if (priceId === process.env.VITE_STRIPE_PRICE_PRO_YEARLY) return 'pro';
  return null;
}

async function alreadyProcessed(eventId: string) {
  const sb = getServiceClient();
  const { data, error } = await sb
    .from('processed_webhook_events')
    .insert({ event_id: eventId })
    .select()
    .maybeSingle();
  if (error && (error as any).code !== '23505') return false;
  return data === null;
}

async function assignFoundingSeatIfNeeded(userId: string) {
  const sb = getServiceClient();
  const { data: existing } = await sb
    .from('subscriptions')
    .select('founding_seat_number')
    .eq('user_id', userId)
    .maybeSingle();
  if (existing?.founding_seat_number) return existing.founding_seat_number;

  const { data: maxRow } = await sb
    .from('subscriptions')
    .select('founding_seat_number')
    .not('founding_seat_number', 'is', null)
    .order('founding_seat_number', { ascending: false })
    .limit(1)
    .maybeSingle();
  return ((maxRow?.founding_seat_number ?? 0) as number) + 1;
}

async function upsertFromSubscription(sub: Stripe.Subscription, userIdOverride?: string) {
  const sb = getServiceClient();
  const userId = userIdOverride ?? (sub.metadata?.supabase_user_id as string | undefined);
  if (!userId) return;

  const priceId = sub.items.data[0]?.price?.id;
  let tier = tierFromPriceId(priceId) ?? (sub.metadata?.tier as 'pro' | 'founding' | undefined);
  if (!tier) tier = 'pro';

  const active = sub.status === 'active' || sub.status === 'trialing' || sub.status === 'past_due';
  const finalTier = active ? tier : 'free';

  const row: Record<string, unknown> = {
    user_id: userId,
    tier: finalTier,
    stripe_customer_id: typeof sub.customer === 'string' ? sub.customer : sub.customer.id,
    stripe_subscription_id: sub.id,
    status: sub.status,
    current_period_end: sub.items.data[0]?.current_period_end
      ? new Date(sub.items.data[0].current_period_end * 1000).toISOString()
      : null,
  };

  if (finalTier === 'founding') {
    row.founding_seat_number = await assignFoundingSeatIfNeeded(userId);
  }

  await sb.from('subscriptions').upsert(row, { onConflict: 'user_id' });
}

export default async function handler(req: VercelRequest, res: VercelResponse) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  const sig = (req.headers['stripe-signature'] as string) ?? '';
  const raw = await readRawBody(req);

  const secrets = [process.env.STRIPE_WEBHOOK_SECRET_NEW, process.env.STRIPE_WEBHOOK_SECRET].filter(
    Boolean,
  ) as string[];

  let event: Stripe.Event | null = null;
  let lastErr: unknown = null;
  for (const secret of secrets) {
    try {
      event = stripe.webhooks.constructEvent(raw, sig, secret);
      break;
    } catch (e) {
      lastErr = e;
    }
  }
  if (!event) {
    res.status(400).json({ error: 'Invalid signature', detail: String(lastErr) });
    return;
  }

  const isNew = await alreadyProcessed(event.id);
  if (!isNew) {
    res.status(200).json({ received: true, deduped: true });
    return;
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed': {
        const session = event.data.object as Stripe.Checkout.Session;
        const userId =
          (session.metadata?.supabase_user_id as string | undefined) ??
          (session.client_reference_id as string | undefined);
        if (session.subscription && userId) {
          const sub = await stripe.subscriptions.retrieve(session.subscription as string);
          await upsertFromSubscription(sub, userId);
        }
        break;
      }
      case 'customer.subscription.created':
      case 'customer.subscription.updated':
      case 'customer.subscription.deleted': {
        const sub = event.data.object as Stripe.Subscription;
        await upsertFromSubscription(sub);
        break;
      }
      case 'invoice.payment_succeeded': {
        const invoice = event.data.object as Stripe.Invoice & {
          subscription?: string | Stripe.Subscription | null;
        };
        const subId =
          typeof invoice.subscription === 'string'
            ? invoice.subscription
            : invoice.subscription?.id ?? null;
        if (subId) {
          const sub = await stripe.subscriptions.retrieve(subId);
          await upsertFromSubscription(sub);
        }
        break;
      }
      default:
        res.status(200).json({ received: true, ignored: event.type });
        return;
    }
  } catch (e) {
    res.status(500).json({ error: 'Handler failed', detail: String(e) });
    return;
  }

  res.status(200).json({ received: true });
}
