-- Skintel schema v1
-- Paste into Supabase SQL Editor and run.

create extension if not exists "uuid-ossp";

-- ============ products ============
create table if not exists public.products (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  brand text,
  product_name text not null,
  category text,
  outcome text not null check (outcome in ('good','bad','unsure')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists products_user_idx on public.products(user_id);
create index if not exists products_user_outcome_idx on public.products(user_id, outcome);
create index if not exists products_created_idx on public.products(user_id, created_at desc);

-- ============ product_ingredients ============
create table if not exists public.product_ingredients (
  id uuid primary key default uuid_generate_v4(),
  product_id uuid not null references public.products(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  position int not null,
  inci_raw text not null,
  inci_normalized text not null,
  unique (product_id, position)
);
create index if not exists pi_user_idx on public.product_ingredients(user_id);
create index if not exists pi_normalized_idx on public.product_ingredients(user_id, inci_normalized);
create index if not exists pi_product_idx on public.product_ingredients(product_id);

-- ============ subscriptions ============
create table if not exists public.subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  tier text not null default 'free' check (tier in ('free','pro','founding')),
  stripe_customer_id text,
  stripe_subscription_id text,
  status text,
  current_period_end timestamptz,
  founding_seat_number int,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index if not exists subs_customer_idx
  on public.subscriptions(stripe_customer_id)
  where stripe_customer_id is not null;
create unique index if not exists subs_founding_seat_idx
  on public.subscriptions(founding_seat_number)
  where founding_seat_number is not null;

-- ============ processed_webhook_events (idempotency) ============
create table if not exists public.processed_webhook_events (
  event_id text primary key,
  processed_at timestamptz not null default now()
);

-- ============ RLS ============
alter table public.products enable row level security;
alter table public.product_ingredients enable row level security;
alter table public.subscriptions enable row level security;

drop policy if exists "products_own" on public.products;
create policy "products_own" on public.products
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "pi_own" on public.product_ingredients;
create policy "pi_own" on public.product_ingredients
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "subs_read_own" on public.subscriptions;
create policy "subs_read_own" on public.subscriptions
  for select using (auth.uid() = user_id);
-- subscription writes only via service-role (webhook).

-- ============ founding seats RPC ============
create or replace function public.founding_seats_remaining()
returns int language sql security definer stable as $$
  select greatest(0, 500 - (
    select count(*)::int from public.subscriptions where tier = 'founding'
  ));
$$;
grant execute on function public.founding_seats_remaining() to anon, authenticated;

-- ============ updated_at trigger ============
create or replace function public.touch_updated_at()
returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

drop trigger if exists products_touch on public.products;
create trigger products_touch before update on public.products
  for each row execute function public.touch_updated_at();

drop trigger if exists subs_touch on public.subscriptions;
create trigger subs_touch before update on public.subscriptions
  for each row execute function public.touch_updated_at();

-- ============ free-tier hard cap ============
create or replace function public.enforce_free_product_limit()
returns trigger language plpgsql security definer as $$
declare cnt int; t text;
begin
  select s.tier into t from public.subscriptions s where s.user_id = new.user_id;
  if t is null or t = 'free' then
    select count(*) into cnt from public.products where user_id = new.user_id;
    if cnt >= 5 then
      raise exception 'FREE_PLAN_LIMIT' using errcode = 'P0001';
    end if;
  end if;
  return new;
end $$;

drop trigger if exists products_free_cap on public.products;
create trigger products_free_cap before insert on public.products
  for each row execute function public.enforce_free_product_limit();
