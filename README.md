# Skintel

Know what touches your skin. Scan a product's barcode or paste its ingredient list, tell Skintel how
your skin reacted, and it finds the ingredient your breakouts have in common — then scores every new
product against *your* history, not skin in general.

Live at **[skinstel.com](https://www.skinstel.com)** (the domain has an S; the brand is Skintel).

| Part | Stack | Where |
|---|---|---|
| Web app | Vite · React 19 · TypeScript · Tailwind | `src/` |
| API | Vercel Node functions | `api/` |
| Data + auth | Supabase (Postgres, RLS, GoTrue) | `supabase/` |
| Billing | Stripe (web) · StoreKit 2 (iOS) | `api/stripe-*.ts`, `api/apple-*.ts` |
| **iOS app** | Swift 6 · SwiftUI · StoreKit 2 · AVFoundation | **`ios/Skintel/`** |
| Design | 18-surface spec + previews | `designs/` |
| Marketing | Deterministic video compositions | `marketing/video/` |

## Web

```bash
cp .env.example .env.local   # fill in Supabase + Stripe values
npm install
npm run dev                  # http://localhost:5173
npm run build
```

Serverless routes run under `vercel dev`. Handlers use the `(req: VercelRequest, res: VercelResponse)`
signature and relative imports carry a `.js` extension (ESM).

## iOS

The native app lives in `ios/Skintel/` and reuses this backend as-is. See:

- [`IOS_SETUP.md`](IOS_SETUP.md) — open the project, configure signing, App Store Connect products, Supabase Apple provider, server env.
- [`IOS_ARCHITECTURE.md`](IOS_ARCHITECTURE.md) — how the app is put together.
- [`MIGRATION_MAP.md`](MIGRATION_MAP.md) — what was reused, ported, rebuilt or dropped, and why.
- [`DESIGN_REVIEW.md`](DESIGN_REVIEW.md) — where the implementation departs from the spec and what's deferred.
- [`APP_STORE_CHECKLIST.md`](APP_STORE_CHECKLIST.md) — submission readiness.

Quick start on a Mac:

```bash
cd ios/Skintel
cp Config/Config.example.xcconfig Config/Config.xcconfig   # add your DEVELOPMENT_TEAM
open Skintel.xcodeproj                                      # or: brew install xcodegen && xcodegen generate
```

The platform-independent core (models, INCI parsing, culprit correlation, entitlement rules, API clients)
is a SwiftPM package that builds and tests on any machine with a Swift 6 toolchain, Linux included:

```bash
cd ios/Skintel/SkintelCore && swift test
```

`ios/App/` is the previous Capacitor (web-view) wrapper. It is superseded by `ios/Skintel/` and kept only
until it is deliberately removed.

## Database

`supabase/schema.sql` is the base schema; `supabase/migrations/` are applied in order in the Supabase SQL editor.
`0004_apple_iap.sql` is required before the iOS app's purchases can be recorded.

## Claude Code skills

Project skills in `.claude/skills/` — `/advisor`, `/ios-audit`, `/design-review`, `/security-review`,
`/appstore-check`, `/qa`, `/ship-check` — encode the review workflows used to build and gate the iOS app.
