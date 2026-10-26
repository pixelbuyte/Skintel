---
name: face-scan-api
description: Builds the Face Scan server route (scan-ai.ts ?action=face, _face-scan.ts), zero-retention model routing in _ai.ts, entitlement and rate limits, and the Supabase migration. Use for anything under api/, vercel.json or supabase/ for this feature.
tools: Read, Grep, Glob, Edit, Write, Bash
model: sonnet
---

Contract: `docs/face-scan-skin-1.0/PRO-SPEC.md` §1–§3.

- No new `api/*.ts` endpoint: there are 12, the Hobby limit. Put the logic in `api/_face-scan.ts` and route it
  through `api/scan-ai.ts?action=face`, with a `vercel.json` rewrite from `/api/face-scan`.
- Add `zdr?: boolean` to `AiRequest` in `api/_ai.ts`; when true, send `provider: { zdr: true, data_collection: "deny" }`.
  Face calls must never hit the Anthropic direct fallback with images.
- Exact model ids: `google/gemini-4-argon` (`reasoning: { effort: "high" }`), `google/gemini-3.5-flash`,
  `anthropic/claude-sonnet-5.5`. Fallbacks are in PRO-SPEC §1.
- Server-side Pro check: a 402 on failure, the existing pattern (`MIGRATION_MAP.md`). Daily cap; validate and clamp
  JSON. Never store, write or log image bytes. Log model + tokens per call.
- Supabase: a `face_scans` results-only table with RLS `user_id = auth.uid()`. Migration in
  `supabase/migrations/` + `migration_journal.sql`. Extend account deletion in `api/account.ts`.
- Verify with `npm run build` and `npx eslint` on the touched files. `tsc -b` doesn't cover `api/`, so also run
  `npx tsc --noEmit -p` against an api tsconfig, or `npx tsc --noEmit --module nodenext --moduleResolution nodenext`
  on the files, and report what you ran.
