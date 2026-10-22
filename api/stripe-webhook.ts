import Stripe from 'stripe';
import type { VercelRequest, VercelResponse } from '@vercel/node';
import { getServiceClient, readRawBody, sendEmail } from './_lib.js';

export const config = { api: { bodyParser: false } };

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, { apiVersion: '2024-12-18.acacia' as any });

function tierFromPriceId(priceId: string | undefined | null): 'pro' | 'founding' | null {
  if (!priceId) return null;
  if (priceId === process.env.VITE_STRIPE_PRICE_FOUNDING) return 'founding';
  if (priceId === process.env.VITE_STRIPE_PRICE_PRO) return 'pro';
  if (priceId === process.env.VITE_STRIPE_PRICE_PRO_YEARLY) return 'pro';
  if (priceId === process.env.STRIPE_PRICE_LAUNCH_PREPAY) return 'pro';
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
  // Fail safe: only grant a paid tier when the Stripe price_id maps to a known
  // plan (or metadata explicitly carries a recognized tier). An unrecognized or
  // missing price must default to 'free', never 'pro' — otherwise a broken
  // webhook payload would silently grant Pro to anyone.
  const metaTier = sub.metadata?.tier;
  const tier: 'pro' | 'founding' | 'free' =
    tierFromPriceId(priceId) ??
    (metaTier === 'pro' || metaTier === 'founding' ? metaTier : 'free');

  const active = sub.status === 'active' || sub.status === 'trialing' || sub.status === 'past_due';
  const finalTier = active ? tier : 'free';

  const row: Record<string, unknown> = {
    user_id: userId,
    tier: finalTier,
    // Marks the row as web-billed so an Apple sync on the same account never overwrites it.
    source: 'stripe',
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

/** Prepaid launch quarter: one 3-month period at the launch price, then $8.99 monthly. */
async function scheduleMonthlyAfterPrepay(sub: Stripe.Subscription) {
  const monthly = process.env.VITE_STRIPE_PRICE_PRO;
  if (!monthly || sub.schedule) return;
  const schedule = await stripe.subscriptionSchedules.create({ from_subscription: sub.id });
  const first = schedule.phases[0];
  await stripe.subscriptionSchedules.update(schedule.id, {
    end_behavior: 'release',
    phases: [
      {
        items: first.items.map((i) => ({
          price: typeof i.price === 'string' ? i.price : i.price.id,
          quantity: i.quantity ?? 1,
        })),
        start_date: first.start_date,
        end_date: first.end_date,
      },
      { items: [{ price: monthly, quantity: 1 }], duration: { interval: 'month', interval_count: 1 } },
    ],
  });
}

async function sendLaunchWelcome(email: string | null, prepaid: boolean) {
  if (!email) return;
  await sendEmail({
    to: email,
    subject: "You're Skintel+ — here's how to get in",
    html: `
      <div style="font-family:-apple-system,Helvetica,Arial,sans-serif;max-width:520px;margin:0 auto;color:#1A1814;line-height:1.55">
        <h2 style="font-family:Georgia,serif;font-weight:400;font-size:26px;margin:0 0 10px">You're Skintel+.</h2>
        <p style="color:#5E554C">${prepaid ? 'Your first 3 months are paid' : 'Your first 3 months are $6.49 each'}, then it's $8.99/month. Cancel any time.</p>
        <p style="color:#5E554C"><strong>To use it:</strong> open Skintel on your iPhone and sign in with <strong>${email}</strong>. That's the account Skintel+ is on.</p>
        <p style="color:#5E554C">New to Skintel? Tap <em>Continue with email</em>, then <em>Forgot password?</em> to set a password for this address.</p>
        <a href="https://apps.apple.com/app/id6812903021" style="display:inline-block;margin-top:10px;background:#A35848;color:#FFFEFA;padding:12px 26px;border-radius:999px;text-decoration:none;font-weight:600">Get the app</a>
        <p style="color:#8A7A6C;font-size:12px;margin-top:22px">Billed by Skintel through Stripe, not Apple. Manage or cancel any time from the link in your Stripe receipt, or write to hello@skinstel.com.</p>
      </div>`,
  });
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
        let userId =
          (session.metadata?.supabase_user_id as string | undefined) ??
          (session.client_reference_id as string | undefined);
        const guestEmail =
          typeof session.customer_details?.email === 'string'
            ? session.customer_details.email.toLowerCase()
            : null;
        let signInLink: string | null = null;

        // Guest founding purchase: no account yet — create (or match) one from
        // the email Stripe collected, and mint a magic link for the welcome email.
        const guestFounding =
          session.mode === 'payment' && session.payment_status === 'paid' && session.metadata?.tier === 'founding';
        // Website launch offer: a subscription bought with only an email. Skintel+ goes to
        // the account with that email (the one they sign in to the app with), created if new.
        const guestLaunch = session.mode === 'subscription' && !!session.metadata?.launch;
        if (!userId && (guestFounding || guestLaunch) && guestEmail) {
          const sb = getServiceClient();
          const { data: created, error: createErr } = await sb.auth.admin.createUser({
            email: guestEmail,
            email_confirm: true,
          });
          if (!createErr && created?.user) {
            userId = created.user.id;
          }
          // New or pre-existing account — either way, resolve the id and a sign-in link
          const { data: linkData } = await sb.auth.admin.generateLink({
            type: 'magiclink',
            email: guestEmail,
          });
          if (linkData?.user) userId = userId ?? linkData.user.id;
          signInLink = linkData?.properties?.action_link ?? null;
        }

        if (session.subscription && userId) {
          let sub = await stripe.subscriptions.retrieve(session.subscription as string);
          if (guestLaunch) {
            // Later subscription events find the account through this metadata.
            sub = await stripe.subscriptions.update(sub.id, {
              metadata: { ...sub.metadata, supabase_user_id: userId },
            });
            if (session.metadata?.launch === 'prepay') await scheduleMonthlyAfterPrepay(sub);
            await sendLaunchWelcome(guestEmail, session.metadata?.launch === 'prepay');
          }
          await upsertFromSubscription(sub, userId);
        } else if (
          session.mode === 'payment' &&
          session.payment_status === 'paid' &&
          userId &&
          session.metadata?.tier === 'founding'
        ) {
          const sb = getServiceClient();
          const seatNumber = await assignFoundingSeatIfNeeded(userId);
          const customerId =
            typeof session.customer === 'string'
              ? session.customer
              : session.customer?.id ?? null;
          await sb.from('subscriptions').upsert(
            {
              user_id: userId,
              tier: 'founding',
              status: 'active',
              stripe_customer_id: customerId,
              stripe_subscription_id: null,
              current_period_end: null,
              founding_seat_number: seatNumber,
            },
            { onConflict: 'user_id' },
          );
          const customerEmail =
            typeof session.customer_details?.email === 'string'
              ? session.customer_details.email
              : null;
          if (customerEmail) {
            await sendEmail({
              to: customerEmail,
              subject: `You're Founding Member #${seatNumber} — welcome to Skintel`,
              html: `
                <div style="font-family:sans-serif;max-width:520px;margin:0 auto;color:#1a1a1a">
                  <h2 style="font-size:24px;margin-bottom:8px">You're in. Welcome, Founding Member #${seatNumber}.</h2>
                  <p style="color:#555;line-height:1.6">
                    Your account now has 3 months of Skintel Pro — ingredient scanning, conflict detection, personalized routine builder, everything.
                  </p>
                  <p style="color:#555;line-height:1.6">
                    No subscription. No auto-renew. You're locked in before the iOS launch.
                  </p>
                  <a href="${signInLink ?? 'https://skinstel.com/app'}" style="display:inline-block;margin-top:16px;background:#A35848;color:#fff;padding:12px 28px;border-radius:8px;text-decoration:none;font-weight:600;">
                    ${signInLink ? 'Sign in to Skintel — one click' : 'Open Skintel'}
                  </a>
                  <p style="margin-top:32px;color:#999;font-size:12px;">
                    Skintel · skinstel.com<br>
                    Questions? Reply to this email.
                  </p>
                </div>
              `,
            });
          }
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
