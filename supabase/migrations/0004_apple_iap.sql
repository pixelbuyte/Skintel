-- Apple In-App Purchase support for the native iOS app.
-- Paste into the Supabase SQL editor and run. Additive only; existing Stripe rows are untouched.
--
-- One `subscriptions` row per user stays the single source of truth for entitlement.
-- Stripe (web) writes via api/stripe-webhook.ts; Apple (iOS) writes via api/apple.ts
-- (/api/apple-verify and /api/apple-notifications). `source` records which channel
-- currently owns the row so the app knows where "Manage subscription" should send the user.
--
-- Guarded with IF EXISTS so it also applies cleanly on Supabase preview branches, which run
-- only migrations/* and may not have schema.sql (where `subscriptions` is created) applied.

alter table if exists public.subscriptions
  add column if not exists source text
    check (source in ('stripe', 'apple', 'grant')),
  add column if not exists apple_original_transaction_id text,
  add column if not exists apple_product_id text;

do $$
begin
  if to_regclass('public.subscriptions') is not null then
    create unique index if not exists subs_apple_original_tx_idx
      on public.subscriptions(apple_original_transaction_id)
      where apple_original_transaction_id is not null;

    -- Rows that already have a Stripe customer were written by the webhook.
    update public.subscriptions
       set source = 'stripe'
     where source is null and stripe_customer_id is not null;
  end if;
end $$;

-- Founding seats are allocated with max()+1 in application code, which can collide
-- under concurrent purchases. A sequence makes the allocation atomic; both the Stripe
-- webhook and the Apple verify route should call founding_next_seat() instead.
create sequence if not exists public.founding_seat_seq start 1;

create or replace function public.founding_next_seat()
returns int language plpgsql security definer as $$
declare n int;
begin
  -- Keep the sequence ahead of any seats assigned before it existed.
  perform setval('public.founding_seat_seq',
                 greatest((select coalesce(max(founding_seat_number), 0) from public.subscriptions),
                          (select last_value from public.founding_seat_seq)), true);
  select nextval('public.founding_seat_seq') into n;
  if n > 500 then
    raise exception 'FOUNDING_SOLD_OUT' using errcode = 'P0001';
  end if;
  return n;
end $$;

revoke all on function public.founding_next_seat() from public;
-- Only the service role (server routes) may allocate seats.
