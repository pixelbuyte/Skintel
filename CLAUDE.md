# Skintel — repo guide for AI agents

Mixed repo: React/Vite web app (`src/`, deployed on Vercel), serverless API (`api/*.ts`),
Supabase backend (`supabase/`), and a **native SwiftUI iOS app** in `ios/Skintel/`
(the `ios/App/` Capacitor wrapper is legacy — do not build on it).

## Model routing (Sep 2026)

| Model | ID | Use for |
|---|---|---|
| Fable 5.1 | `claude-fable-5-1` | **Escalation only.** Hardest/longest-horizon work, or anything Opus 5.5 failed at high effort. |
| Opus 5.5 | `claude-opus-5-5` | **Default.** Features, refactors, migrations, hard bugs, code review. |
| Sonnet 5.5 | `claude-sonnet-5-5` | Small fixes, tweaks, boilerplate, tests, scripts, sub-agents. |
| Haiku 4.5 | `claude-haiku-4-5-20251001` | Pure volume/bulk cheap tasks. |

Routing:

- New app / big feature: Opus 5.5, medium effort.
- Hard bug: Opus 5.5 high effort, then xhigh, then max, then Fable 5.1.
- Small fixes, tweaks, boilerplate, tests: Sonnet 5.5.
- Never downgrade models mid-task on hard work.
- Sub-agents for grunt work (search, boilerplate, tests, scripts) run on Sonnet 5.5.

## Workflow rules

1. Plan first; state the approach in a few lines before editing.
2. Small diffs, one concern per change, no unrelated refactors.
3. Find the root cause before fixing a bug. No symptom patches.
4. Run the build/tests after every change. Never claim it works unverified (how: see Project).
5. Follow existing code conventions.
6. Ask before destructive actions: deleting files, dropping data, force push.
7. End with a short summary: changed, verified, left.

Repo practice: work on a branch, open a PR, the founder reviews and merges. Don't push to `main`.

## Style

Terse, direct, no fluff. Blue/black aesthetic for UI defaults **only when a new UI has no
established design system**. Skintel already has one (cream `F4EDE0`, clay `A35848`, ink
`1A1814`; Instrument Serif / DM Sans / JetBrains Mono; no yellow) — it always wins over the
blue/black default. Tokens: `ios/Skintel/Skintel/DesignSystem/Tokens/`; details in `HANDOFF.md` §6.

## Project

Skintel: scan a skincare product, log how skin reacted, find the ingredient your bad days
share, score new products against *your* history. Brand is **Skintel**; the live domain is
**skinstel.com** (with an S). Product context, AI models, plans: `HANDOFF.md`.
System overview: `docs/ARCHITECTURE.md`.

**Stack**

- Web: React 19, Vite 8, TypeScript 6, Tailwind 3, react-router 7 — `src/`, hosted on Vercel.
- API: Vercel Node functions — `api/*.ts` (ESM; relative imports end in `.js`). Files starting
  `_` are shared modules, not endpoints.
- Data/auth: Supabase Postgres + RLS — `supabase/`. Billing: Stripe (web only), StoreKit 2 (iOS).
- iOS (the product): SwiftUI, iOS 17+, Swift 6 strict concurrency, XcodeGen, local SPM package
  `SkintelCore` — `ios/Skintel/`.

**Commands** (repo root unless noted)

```bash
npm install
npm run dev                   # Vite on :5173; /api is proxied to PRODUCTION skinstel.com
npm run build                 # tsc -b && vite build — the web verification gate (passes on main)
npx eslint src api            # lint; use this, not `npm run lint` (see gotchas)
cd ios/Skintel/SkintelCore && swift test      # 34 core tests; run on Linux; no Mac needed
swiftc -parse <file.swift>                    # syntax-check every Swift file you touched
cd ios/Skintel && xcodegen generate --spec project.yml   # only when adding/removing Swift files
```

**Verifying a change**

- Web/API: `npm run build` plus `npx eslint` on the files you touched. There is no web test runner.
- iOS: `swiftc -parse` on touched files + `swift test` in `SkintelCore`, then push and run Codemagic
  `ios-ci` (simulator build + SkintelTests + SkintelUITests). Do not say iOS "builds" or "works"
  until `ios-ci` is green. The founder starts `ios-release` (TestFlight); agents never do.

**Key folders**

| Path | What |
|---|---|
| `ios/Skintel/Skintel/Features/` | One folder per area (Home, Scanner, Products, Recommend = Ask Skintel, Routine, Subscription, …) |
| `ios/Skintel/Skintel/DesignSystem/` | `SK*` tokens and components — the only place hex values/sizes live |
| `ios/Skintel/SkintelCore/` | Models, API client, pure logic (verdicts, streaks, entitlement) |
| `ios/Skintel/SkintelWidgets/`, `ios/Skintel/Shared/` | Widgets; `Shared/` is compiled into app + extension |
| `api/` | Serverless API (iOS and web both call it); `_ai.ts` routes AI models |
| `src/` | Web app; `src/pages/` routes, `src/components/`, `src/lib/` |
| `supabase/` | `schema.sql`, `migrations/`, `migration_journal.sql` |
| `codemagic.yaml` | iOS CI/CD |

## iOS work

Read `ios/Skintel/CLAUDE.md` before touching anything under `ios/Skintel/`. Key facts:

- **The developer has no Mac.** Nothing you write in Swift is compiled locally — the only
  compiler is Codemagic CI. Every error you introduce costs a ~6 minute CI round-trip, so
  cross-check member names, signatures, and imports against the actual declarations in this
  repo before committing. Do not guess APIs.
- CI is `codemagic.yaml` at this root: workflow `ios-ci` (simulator build + all tests, no
  signing needed) and `ios-release` (TestFlight, requires Apple credentials in Codemagic).
- The branch for all iOS work is `main`. The old `iOS-app` branch predates the native app.

## Secrets

Never commit: Apple keys, Supabase service-role key, Stripe secret/webhook keys, AI provider
keys. Server secrets live in Vercel env config; Apple credentials live in Codemagic's
App Store Connect integration. The Supabase **anon** key and API base URL are public by
design (RLS-protected) and appear in `ios/Skintel/Config/Config.example.xcconfig` — that is
intentional, do not "fix" it, and do not add real secrets to any xcconfig.

## Known gotchas

- **Vercel Hobby limit is 12 functions, and `api/` has exactly 12** (every `api/*.ts` not starting
  with `_`). A 13th endpoint fails the deploy. Add logic as a `_module.ts` or fold it into an existing
  function via `?action=` plus a `vercel.json` rewrite (as `apple.ts`, `account.ts`, `recommend.ts` do).
- **`npm run lint` from the root fails** whenever agent worktrees exist: eslint also scans
  `.claude/worktrees/*` and dies on multiple `tsconfigRootDir`s (658 errors). Use `npx eslint src api`.
  Even scoped, ~91 lint errors already exist (mostly `no-explicit-any`) — lint is not a green gate;
  just don't add new ones.
- **`tsc -b` covers `src/` and `vite.config.ts` only.** `api/` is not type-checked by `npm run build`
  (Vercel compiles it), so a broken `api/` file can pass the build.
- **`npm run dev` talks to production**: `vite.config.ts` proxies `/api` to `https://skinstel.com`.
- **Naming drift:** brand Skintel, domain skinstel.com, legacy "Skinstel" (the `SkinstelMascot`
  package; a misspelt `com.skinstel.app` App ID also exists in the Apple Developer portal). The real
  bundle id is `com.skintel.app`.
- **`ios/Skintel/CLAUDE.md` is stale on CI names**: it says integration `skintel_app_store_connect` and
  env group `ios_release`; `codemagic.yaml` actually uses integration `codemagic1` and group
  `skintel_ios_release`. Trust `codemagic.yaml`.
- **`memory/` at the repo root holds 27 tracked files of unrelated personal notes** (video editing,
  security tooling, other projects, local Windows paths). Not project context — don't rely on it, and
  ask the founder before deleting it or making the repo public.
- Stray files: `src/components/_BulkPhotoUpload.tsx.bak`; root `test-*.mjs` / `find-*.mjs` are ad-hoc
  probes against live APIs, not a test suite.
- The web bundle ships as one ~1.15 MB chunk (Vite warns); nothing is code-split.
- More iOS-specific traps (name collisions with StoreKit, persisted-model decoding, injectable clocks,
  XcodeGen): `ios/Skintel/CLAUDE.md`.
