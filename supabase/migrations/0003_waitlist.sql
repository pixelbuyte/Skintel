-- Waitlist for iOS launch + founding offer funnel.

create table if not exists public.waitlist (
  id uuid primary key default uuid_generate_v4(),
  email text not null unique,
  signed_up_at timestamptz not null default now(),
  converted boolean not null default false,
  source text
);

create index if not exists waitlist_signed_up_idx on public.waitlist(signed_up_at desc);

alter table public.waitlist enable row level security;

-- Public can insert (anon waitlist signup). Service role only for read/update/delete.
drop policy if exists "waitlist_insert_public" on public.waitlist;
create policy "waitlist_insert_public" on public.waitlist
  for insert
  to anon, authenticated
  with check (true);

-- No select/update/delete policy → only service role bypasses RLS.
