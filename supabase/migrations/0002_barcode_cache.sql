-- Paste into Supabase SQL editor.
-- barcode_cache: shared cache of UPC -> ingredients to avoid re-paying Claude.
-- Writes flow through service role from api/_barcode-lookup.ts only.

create table if not exists public.barcode_cache (
  upc text primary key,
  brand text,
  product_name text,
  ingredients text not null,
  source text not null,
  created_at timestamptz default now() not null
);

alter table public.barcode_cache enable row level security;

-- Public reads: any auth or anon user can read cached lookups.
drop policy if exists "read cache" on public.barcode_cache;
create policy "read cache" on public.barcode_cache for select using (true);

-- No client insert / update / delete policy.
-- Service role bypasses RLS; without an explicit write policy,
-- anon/auth clients cannot poison the cache.
