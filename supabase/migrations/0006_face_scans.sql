-- Face Scan Pro (docs/face-scan-skin-1.0/PRO-SPEC.md §2-§3).
-- Paste into the Supabase SQL editor and run. Additive only. Not applied by any agent.
--
-- face_scans: RESULTS ONLY (validated scores, notes, report JSON). Never photos, crops or face
--   meshes: those stay on the device (PRO-SPEC §2). The app reads and writes its own rows
--   through RLS; deleting a scan in the app deletes the row.
-- face_scan_usage: one row per /api/face-scan request (stage, model, token counts, no image
--   data). Written and read only by api/_face-scan.ts with the service role; it drives the
--   per-user daily cap and shows the real cost per 7-day cycle (PRO-SPEC §1).
--
-- Both tables reference auth.users ON DELETE CASCADE, so api/account.ts "delete" (one hard
-- delete of the auth user) removes them with everything else. api/account.ts export-data
-- includes face_scans (results only).

create table if not exists public.face_scans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  cycle_id text not null,
  day smallint not null check (day between 1 and 31),
  stage text not null check (stage in ('baseline','daily','final','report')),
  result jsonb not null check (pg_column_size(result) <= 65536),
  created_at timestamptz not null default now()
);
create index if not exists face_scans_user_cycle_idx
  on public.face_scans(user_id, cycle_id, created_at desc);

alter table public.face_scans enable row level security;

drop policy if exists "face_scans_select_own" on public.face_scans;
create policy "face_scans_select_own" on public.face_scans
  for select to authenticated using (user_id = auth.uid());

drop policy if exists "face_scans_insert_own" on public.face_scans;
create policy "face_scans_insert_own" on public.face_scans
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists "face_scans_delete_own" on public.face_scans;
create policy "face_scans_delete_own" on public.face_scans
  for delete to authenticated using (user_id = auth.uid());

-- No update policy: a stored result is never edited.

create table if not exists public.face_scan_usage (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  stage text not null check (stage in ('baseline','daily','final','report')),
  model text,
  prompt_tokens int not null default 0,
  completion_tokens int not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists face_scan_usage_user_created_idx
  on public.face_scan_usage(user_id, created_at);

alter table public.face_scan_usage enable row level security;

-- No policies on purpose: anon and signed-in clients can neither read nor write this table.
-- The service role bypasses RLS, and only api/_face-scan.ts uses it.
