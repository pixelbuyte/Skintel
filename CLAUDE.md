# Skintel — repo guide for AI agents

Mixed repo: React/Vite web app (`src/`, deployed on Vercel), serverless API (`api/*.ts`),
Supabase backend (`supabase/`), and a **native SwiftUI iOS app** in `ios/Skintel/`
(the `ios/App/` Capacitor wrapper is legacy — do not build on it).

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
