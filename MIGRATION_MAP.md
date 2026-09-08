# Skintel — Web → Native iOS Migration Map

Audit date: 2026-09-07. Source of truth for what the product *does*: the shipped web app
(`src/`, `api/`, `supabase/`). Source of truth for how the iOS app *looks*:
`designs/skintel-ios-designs.html` (18 surfaces). No Figma file is referenced anywhere in
the repository; the HTML spec is the final design artifact. Where the spec and the shipped
product disagree, the product wins on behaviour and the spec wins on layout — each case is
listed under **Conflicts** below.

## Decisions

| Topic | Decision | Why |
|---|---|---|
| Brand | **Skintel** (app name, wordmark). Domain is `skinstel.com`. | Every artifact — Capacitor config, design spec, DB, web copy — says Skintel. The domain differs because `skintel.com/.app/.io` belong to other companies (see `memory/`). No rename. |
| Location | `ios/Skintel/` (new native app). `ios/App/` (Capacitor webview) is **deprecated**, left in place until you confirm deletion. | The brief forbids a WKWebView wrapper; the Capacitor project is exactly that. Its bundle id, icon and permission strings are reused. |
| Branch | `claude/skintel-ios-design-f8c85l`, restarted from `main` after PR #15 merged. | It is the existing iOS-intended branch; the brief says use one if it exists. |
| Bundle id | `com.skintel.app` | Carried over from the Capacitor project — may already be registered in App Store Connect. |
| Deployment target | **iOS 17.0**, Swift 6 language mode, Xcode 16+ (26 works). | Everything used (`@Observable`, StoreKit 2, VisionKit `DataScannerViewController`, `PhotosPicker`) is ≤ iOS 17. 18-only APIs would cut devices for no gain. |
| Architecture | Local SwiftPM package **`SkintelCore`** (models, INCI/culprit logic, entitlement rules, Supabase + API clients) + SwiftUI app target **`Skintel`**. | The core has no UIKit dependency, so it compiles and its tests run on Linux with the Swift 6.1 toolchain — the only real verification available in this environment. |
| Project file | `project.yml` (XcodeGen) **and** the generated `Skintel.xcodeproj` are both committed. | Regenerate with `xcodegen generate` after adding files; the committed project opens without installing anything. |
| Auth providers | **Sign in with Apple** (native, Supabase `apple` provider via id token) + **email / password** (identical accounts to the web). Password reset sends the web reset email. | Web `useAuth.tsx` is email/password only today; Google was removed. Apple is what the design leads with and is the App Store-native choice. Google is a follow-up (needs Google Cloud + Supabase provider config) — see DESIGN_REVIEW. |
| Skin profile | Stored in Supabase **`auth.users.user_metadata`** (`skin_type`, `concerns`, `onboarding_complete`) via `PUT /auth/v1/user`. | No `profiles` table exists and no API consumes the profile yet. `user_metadata` needs no migration, is per-user by construction, and is readable from the session. Server-side personalisation by skin type is a follow-up API change. |
| Product score ("82") | Real: it is `result.score` from `POST /api/scan-ai`. Persisted **on device** per product (`ScanStore`), mirroring the web's `localStorage['skintel:scans:v1']`. | The `products` table has no score column. An optional migration for a `product_scans` table is in `IOS_SETUP.md`; not required to ship. |
| "Shelf Score" | **Not built.** | It exists only in the design and marketing. The brief says do not invent a score. Home shows the four real counts from product outcomes, exactly as `Dashboard.tsx` does. |
| Journal states | The four DB-enforced values: `clear / mild / moderate / breakout`. | The spec shows three (Worked/Unsure/Broke out); the CHECK constraint and `/api/journal` accept four. |
| Journal photo | **Not built.** | `photo_url` is a bare string; no storage bucket or upload path exists on the web either. |
| Routine | Persisted on device (mirrors `localStorage['skintel:routine:v1']`), conflicts via `POST /api/analyze-routine`. | No routine table exists; conflict rules live in the API prompt, not in code. |
| Culprits | Local co-occurrence engine (`correlate.ts` ported exactly) **plus** `POST /api/journal?action=analyze` suspects (Pro). | Both are what the web does. |
| Monetisation | **StoreKit 2** for in-app purchase; Stripe stays for web. New `api/apple-verify.ts` + `api/apple-notifications.ts` write to the same `subscriptions` table. | Apple requires IAP for digital features. One server-side row remains the single source of truth for both channels. |
| StoreKit products | `com.skintel.app.pro.monthly` (auto-renew, $9), `com.skintel.app.pro.yearly` (auto-renew, $79), `com.skintel.app.founding` (non-renewing, $20, 3 months, 500 seats via RPC). | Mirrors `src/lib/stripe-prices.ts` + `Discount.tsx`. Prices displayed come from StoreKit, never hard-coded. |
| Free cap | Handled by the DB trigger (`FREE_PLAN_LIMIT`, 5 products). The app maps that error to the paywall. | Already enforced server-side; do not duplicate. |
| Entitlement rule | `isPro = status ∈ {active, trialing} && tier ∈ {pro, founding}` — the **server's** rule. | The web hook checks tier only and disagrees with the API (a cancelled Pro looks paid, then gets 402). Fixed in the port. |
| Widgets | Deferred. | Design surface 18 is not part of the shipped product. |
| Analytics | No SDK. `Analytics` protocol with an `os_log` sink; product events listed in `IOS_ARCHITECTURE.md`. | Vercel Analytics is web-only; the brief forbids adding SDKs speculatively. |

## Feature map

Legend — **REUSE**: called as-is · **API**: reused through the existing endpoint · **PORT**: logic rewritten in Swift, behaviour preserved · **NATIVE**: rebuilt with platform UI · **DEPRECATE**: not carried over.

| Existing feature | Location | Strategy | iOS home |
|---|---|---|---|
| Supabase auth (email/password) | `src/hooks/useAuth.tsx`, GoTrue | **API** (`/auth/v1/token`, `/signup`, `/recover`, `/user`) | `Core/Auth/AuthService` |
| Session persistence | `localStorage` via supabase-js | **NATIVE** → Keychain | `Core/Auth/KeychainSessionStore` |
| Route guard | `ProtectedRoute.tsx` | **NATIVE** → `AppRouter` state machine | `App/AppRouter` |
| Products CRUD | `src/hooks/useProducts.ts` (PostgREST) | **API** (`/rest/v1/products?select=*,product_ingredients(*)`) | `Features/Products` |
| Free-tier cap | DB trigger `enforce_free_product_limit` | **REUSE** | `SkintelCore/APIError.freePlanLimit` |
| INCI parse/normalise | `src/lib/inci.ts` | **PORT** (exact) | `SkintelCore/Logic/INCI` |
| Ingredient knowledge + buckets + local verdict | `src/lib/ingredient-knowledge.ts` | **PORT** (exact, incl. its separate normaliser) | `SkintelCore/Logic/IngredientKnowledge` |
| Culprit correlation | `src/lib/correlate.ts` | **PORT** (exact) | `SkintelCore/Logic/Correlate` |
| Barcode scanning | `react-zxing` in `BarcodeScanner.tsx` | **NATIVE** → AVFoundation metadata output (EAN-8/13, UPC-E) | `Features/Scanner/BarcodeScannerView` |
| Barcode → product | `GET /api/lookup?mode=barcode&upc=` | **API** | `SkintelCore/API/SkintelAPI.lookupBarcode` |
| Label photo OCR | `PhotoUpload.tsx` → `POST /api/scan-photo` | **API**; `PhotosPicker` + camera capture, resized ≤1600px JPEG | `Features/Scanner/PhotoScan` |
| URL import | `ImportFromUrl.tsx` → `/api/lookup?mode=url` | **API** | `Features/Scanner/URLImport` |
| Product search | `/api/lookup?mode=search&q=` | **API** | `Features/Scanner/ProductSearch` |
| AI verdict + score | `POST /api/scan-ai` | **API** | `Features/Analysis/VerdictView` |
| Scan history | `localStorage['skintel:scans:v1']` | **NATIVE** → `ScanStore` (Application Support, Codable) | `Core/Persistence/ScanStore` |
| Journal CRUD + AI analysis | `POST/GET/DELETE /api/journal`, `?action=analyze` | **API** | `Features/Journal` |
| Routine templates + AM/PM | `Routine.tsx` (localStorage) | **PORT** templates, **NATIVE** persistence | `Features/Routine` |
| Routine conflicts | `POST /api/analyze-routine` | **API** | `Features/Routine/RoutineAnalysis` |
| Compare | `POST /api/lookup?mode=compare` | **API** | `Features/Compare` |
| Recommend | `POST /api/recommend` | **API** | `Features/Recommend` |
| Subscription status | `subscriptions` row (read-own RLS) | **API** (`/rest/v1/subscriptions`) | `SkintelCore/Models/Subscription` |
| Founding seats | RPC `founding_seats_remaining` | **API** (`/rest/v1/rpc/...`) | `Features/Subscription` |
| Stripe checkout / portal | `/api/stripe-checkout`, `/api/stripe-portal` | **DEPRECATE in-app** (Apple IAP rules); portal link kept in Settings for Stripe-origin subscribers | `Features/Settings` |
| Export data | `GET /api/export-data` | **API** → share sheet | `Features/Settings` |
| Delete account | `POST /api/delete-account` | **API** | `Features/Settings` |
| Display name / avatar | `localStorage` | **NATIVE** → `user_metadata.display_name` | `Features/Settings` |
| Offline barcode queue | `src/lib/offlineQueue.ts` | **DEPRECATE** (retry UI instead) | — |
| Preview/demo mode | `src/lib/preview.ts` | **DEPRECATE** in app; mock services exist for previews/tests only | `Skintel/Previews` |
| Landing / Pricing / Discount pages | marketing web | **DEPRECATE** (paywall replaces) | — |
| Capacitor wrapper | `ios/App`, `capacitor.config.ts`, `src/lib/native.ts` | **DEPRECATE** | — |
| Haptics | `src/lib/haptics.ts` | **NATIVE** → `UIFeedbackGenerator` | `Core/Utilities/Haptics` |

## Backend contracts the app depends on

Base URLs: Supabase `https://fgttlowgvoonedqglyle.supabase.co`, API `https://www.skinstel.com/api`.
Every `/api/*` call sends `Authorization: Bearer <supabase access token>`; the server validates it with the service role (`api/_lib.ts:getUserFromAuthHeader`). Pro-gated routes answer **402** `{error:"Pro required"}`; the app maps that to the paywall.

| Endpoint | Pro | Request → Response |
|---|---|---|
| `GET /api/lookup?mode=barcode&upc=` | yes | → `{brand, productName, ingredients, source}` / 404 |
| `GET /api/lookup?mode=search&q=` | yes | → `{results:[{code, productName, brand, ingredients, imageUrl}]}` |
| `POST /api/lookup?mode=url` `{url}` | yes | → `{brand, productName, ingredients}` / 422 |
| `POST /api/lookup?mode=compare` `{products:[{name,inci}]}` | yes | → `{items:[{name,verdict,score,short,keyConcerns,keyWins}], winner:{index,reason}}` |
| `POST /api/scan-ai` `{inci, matches:[{name,risk,badCount}]}` | yes | → `{result:{verdict,score,summary,flags:[{ingredient,level,reason,source}],notes}}` |
| `POST /api/scan-photo` `{imageBase64, mimeType}` | yes | → `{result:{brand,productName,ingredients}}` |
| `GET/POST/DELETE /api/journal` | no | GET → `{entries}`; POST `{entryDate, condition, notes?, photoUrl?}` → `{entry}`; DELETE `?id=` |
| `POST /api/journal?action=analyze` | yes | → `{result:{summary,suspects:[{productOrIngredient,confidence,reasoning,evidenceDates}],patterns,recommendations}}` |
| `POST /api/analyze-routine` `{amProductIds, pmProductIds}` | yes | → `{result:{amVerdict,pmVerdict,conflicts:[{products,issue,severity,fix}],redundancies,suggestions}}` |
| `POST /api/recommend` `{goal,budget,maxPrice?,count?,notes?}` | yes | → `{result:{recommendations:[...]}, meta}` |
| `GET /api/export-data` | no | → JSON attachment |
| `POST /api/delete-account` | no | → `{ok:true}` |
| `POST /api/apple-verify` **(new)** | no | `{signedTransaction}` → `{subscription}` |
| `POST /api/apple-notifications` **(new)** | — | App Store Server Notifications V2 |

## Conflicts resolved (product vs design)

1. **Paywall offer** — spec: $29/yr, 100 seats. Product: $20 once for 3 months, 500 seats; Pro $9/mo, $79/yr. → Product. Layout from spec.
2. **Sign-in providers** — spec: Apple/Google/magic link. Product: email/password. → Apple + email/password; Google and magic link deferred.
3. **Journal states** — spec: 3. Product/DB: 4. → 4.
4. **Home stats** — spec calls them "journal stats". `Dashboard.tsx` counts product outcomes. → Product outcome counts (`Logged/Worked/Unsure/Broke out` = total/good/unsure/bad).
5. **Onboarding** — spec only. → Built, persisted to `user_metadata`.
6. **Scanner access** — spec implies open. API returns 402 for free tier. → Paywall for free users, exactly as the web's `canUseScanner`.
7. **Culprit timeline bars** — spec shows use→breakout timeline. Product data has no per-day product usage. → Culprits screen shows the real signals: co-occurrence counts and, for Pro, the journal AI's suspects with confidence and evidence dates.

## Known product defects found during the audit (not silently fixed)

- Founding tier has no expiry: webhook writes `current_period_end: null`. The 3-month promise is not enforced for Stripe founders. The Apple path sets a real expiry; the Stripe path is unchanged and noted in `APP_STORE_CHECKLIST.md`.
- `assignFoundingSeatIfNeeded` (`api/stripe-webhook.ts`) is race-prone on the unique seat index. The Apple verify route reuses the same helper so the behaviour is consistent; a DB-side sequence is the proper fix.
- Two INCI normalisers coexist (`inci.ts` vs `ingredient-knowledge.ts`). Both are ported exactly so keys stay compatible with existing rows.
