# Skintel architecture

Short map of how the pieces fit. Deeper docs: `HANDOFF.md` (start here), `IOS_ARCHITECTURE.md`
(app internals), `MIGRATION_MAP.md` (settled decisions), `IOS_SETUP.md` (signing, App Store Connect).

```
iOS app (SwiftUI)  ─┐                       ┌─ Supabase: Postgres + Auth + RLS
                    ├─►  Vercel  /api/*  ───┤
Web app (React)    ─┘    (Node functions)    ├─ OpenRouter → Gemini / GPT / Claude models
                                            │   (Anthropic direct as fallback)
                                            ├─ Apple: App Store Server API + notifications
                                            └─ Stripe (web purchases only)
```

## Clients

- **iOS app** (`ios/Skintel/`) is the product. `SkintelCore` (SPM) holds models, the API/Supabase
  clients and pure logic (ingredient parsing, correlation, entitlement) with no UI, Keychain or
  StoreKit, so it builds and tests on Linux. The app target composes it: stores injected through
  `AppEnvironment`, one `NavigationStack` per tab, all styling from `DesignSystem/`.
- **Widgets** (`SkintelWidgets/`) share `Shared/` (App Group defaults, deep links) with the app.
  They do not link `SkintelCore`.
- **Web app** (`src/`) is the marketing site and a browser client for the same API.
- `ios/App/` is a legacy Capacitor wrapper. Do not build on it.

## API (`api/`)

Vercel Hobby allows 12 functions, so related endpoints share one file and `vercel.json` rewrites the
public paths (`/api/apple-verify` → `apple.ts?action=verify`, `/api/assistant` →
`recommend.ts?action=assistant`, `/api/export-data` and `/api/delete-account` → `account.ts`).
Files starting `_` are shared modules, not endpoints.

| Function | Job |
|---|---|
| `lookup`, `scan-ai`, `scan-photo` | Barcode/link/search lookup, verdict scan, label-photo reading |
| `recommend`, `analyze-routine`, `journal` | Ask Skintel + picks, routine conflict checks, journal analysis |
| `apple` | StoreKit transaction verification and App Store server notifications |
| `stripe-checkout`, `stripe-portal`, `stripe-webhook` | Web billing |
| `account`, `waitlist` | Data export/delete, waitlist signup |

AI calls go through `_ai.ts` (OpenRouter first, Anthropic fallback); model choices are in
`HANDOFF.md` §4. Every AI endpoint checks the caller's entitlement server-side.

## Data (`supabase/`)

`products` and `product_ingredients` (per-user shelf, RLS `*_own`; a DB trigger enforces the
5-product free cap), `subscriptions`, `processed_webhook_events`, `barcode_cache`, `waitlist`,
`skin_journal`. Scan verdicts are kept on device, not in the database.

## Flows

- **Scan:** camera/paste/photo/link → `ScanCandidate` (`/api/lookup` or `/api/scan-photo`) →
  `/api/scan-ai` with the user's own reaction history as `matches` → verdict stored on device →
  optional "Save to shelf" writes product + ingredients to Supabase.
- **Entitlement:** the server decides. iOS buys via StoreKit 2 → sends the signed transaction to
  `/api/apple-verify` → server verifies against Apple's root CA and upserts `subscriptions` → the
  app reads the result. Apple notifications and Stripe webhooks keep the row current. The client
  never grants Skintel+ itself, and the iOS app never links to web checkout.
- **Session:** Supabase session lives in the Keychain (`SessionManager`), refreshed a minute before
  expiry; onboarding completion is a flag in the Supabase user metadata.

## Build and release

Push a branch → Codemagic `ios-ci` (simulator build + all tests) → PR → founder merges → Vercel
deploys web/API. TestFlight is Codemagic `ios-release`, started by the founder from `main`
(internal testing only). Codemagic is the only Swift compiler — there is no local Mac.
