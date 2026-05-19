import Stripe from 'stripe';
import { getServiceClient } from './_lib';

export const config = { runtime: 'nodejs' };

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-12-18.acacia' as any });

function tierFromPriceId(priceId: string | undefined | null): 'pro' | 'founding' | null {
  if (!priceId) return null;
  if (priceId === process.env.VITE_STRIPE_PRICE_FOUNDING) return 'founding';
  if (priceId === process.env.VITE_STRIPE_PRICE_PRO) return 'pro';
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
  const next = ((maxRow?.founding_seat_number ?? 0) as number) + 1;
  return next;
}

async function upsertFromSubscription(
  sub: Stripe.Subscription,
  userIdOverride?: string,
) {
  const sb = getServiceClient();
  const userId =
    userIdOverride ??
    (sub.metadata?.supabase_user_id as string | undefined);
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
    current_period_end: sub.current_period_end
      ? new Date(sub.current_period_end * 1000).toISOString()
      : null,
  };

  if (finalTier === 'founding') {
    row.founding_seat_number = await assignFoundingSeatIfNeeded(userId);
  }

  await sb.from('subscriptions').upsert(row, { onConflict: 'user_id' });
}

export default async function handler(req: Request) {
  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), { status: 405 });
  }

  const sig = req.headers.get('stripe-signature') ?? '';
  const raw = await req.text();

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
    return new Response(JSON.stringify({ error: 'Invalid signature', detail: String(lastErr) }), {
      status: 400,
    });
  }

  const isNew = await alreadyProcessed(event.id);
  if (!isNew) {
    return new Response(JSON.stringify({ received: true, deduped: true }), { status: 200 });
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
        const invoice = event.data.object as Stripe.Invoice;
        if (invoice.subscription) {
          const sub = await stripe.subscriptions.retrieve(invoice.subscription as string);
          await upsertFromSubscription(sub);
        }
        break;
      }
      default:
        return new Response(
          JSON.stringify({ received: true, ignored: event.type }),
          { status: 200 },
        );
    }
  } catch (e) {
    return new Response(JSON.stringify({ error: 'Handler failed', detail: String(e) }), {
      status: 500,
    });
  }

  return new Response(JSON.stringify({ received: true }), { status: 200 });
}
