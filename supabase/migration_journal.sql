-- Skintel migration: skin_journal
-- Paste into Supabase SQL Editor and run.

create table if not exists public.skin_journal (
  id uuid primary key default uuid_generate_v4(),
  user_id uuid not null references auth.users(id) on delete cascade,
  entry_date date not null,
  condition text not null check (condition in ('clear','mild','moderate','breakout')),
  notes text,
  photo_url text,
  created_at timestamptz not null default now()
);
create unique index if not exists skin_journal_user_date_idx on public.skin_journal(user_id, entry_date);
create index if not exists skin_journal_user_idx on public.skin_journal(user_id, entry_date desc);
alter table public.skin_journal enable row level security;
drop policy if exists "journal_own" on public.skin_journal;
create policy "journal_own" on public.skin_journal
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);
