# iOS setup

Everything the code cannot do for you, in the order to do it. Each item names the exact value and where
the code consumes it.

## 1. Open and build (5 minutes)

Requirements: macOS with Xcode 16 or newer (26 is fine). Minimum deployment target is iOS 17.

```bash
cd ios/Skintel
cp Config/Config.example.xcconfig Config/Config.xcconfig
# edit Config/Config.xcconfig → DEVELOPMENT_TEAM = <your 10-character Team ID>
open Skintel.xcodeproj
```

`Config.xcconfig` is gitignored. It already contains the Supabase URL, the public anon key and the API base URL —
none of those are secrets (the anon key ships in the web bundle and is protected by Row Level Security).

If you add or move Swift files, regenerate the project so Xcode sees them:

```bash
brew install xcodegen
xcodegen generate          # rewrites Skintel.xcodeproj, Info.plist and Skintel.entitlements from project.yml
```

Build and run on a simulator. The **Skintel** scheme has a StoreKit test configuration attached
(`Skintel/Resources/Skintel.storekit`), so the paywall shows the three products and purchases complete locally
— the backend will reject those local receipts (correct: they are not signed by Apple), which is the expected
"Purchased, but Skintel couldn't confirm it yet" state until real products exist.

Tests: `⌘U` runs `SkintelTests` (app logic) and `SkintelUITests` (launch → welcome → sign-in form). The core
package has its own suite: `cd SkintelCore && swift test` (works on Linux too).

## 2. Apple Developer — identifiers and capabilities

| Item | Value | Consumed by |
|---|---|---|
| App ID | `com.skintel.app` | `project.yml` → `PRODUCT_BUNDLE_IDENTIFIER` |
| Capability | **Sign in with Apple** | `Skintel.entitlements` (`com.apple.developer.applesignin`) |
| Capability | **In-App Purchase** | on by default for App IDs; StoreKit 2 needs no entitlement key |
| Signing | Automatic, with `DEVELOPMENT_TEAM` from `Config.xcconfig` | `project.yml` → `CODE_SIGN_STYLE` |

## 3. App Store Connect — app record and products

1. Create the app with bundle id `com.skintel.app`, name **Skintel**, primary category Lifestyle.
2. Note the numeric **Apple ID** of the app (App Information → General). Set it on the server as
   `APPLE_APP_APPLE_ID` (see §5). Production receipt verification cannot run without it.
3. Create the in-app purchases. Ids and types must match exactly — they are referenced in
   `ios/Skintel/Skintel/Features/Subscription/SubscriptionService.swift` (`ProductID`) and `api/_apple.ts` (`APPLE_PRODUCTS`):

| Product ID | Type | Price | Display name |
|---|---|---|---|
| `com.skintel.app.pro.monthly` | Auto-renewable subscription, group **Skintel Pro**, 1 month | $9.00 | Pro Monthly |
| `com.skintel.app.pro.yearly` | Auto-renewable subscription, same group, 1 year | $79.00 | Pro Yearly |
| `com.skintel.app.founding` | **Non-renewing subscription**, 3 months | $20.00 | Founding member |

   Prices mirror `src/lib/stripe-prices.ts` and `src/pages/Discount.tsx`. The app never hard-codes a price; it
   displays StoreKit's localized `displayPrice`. The 500-seat cap is enforced server-side (`founding_next_seat()`),
   and the paywall hides the founding card when `founding_seats_remaining()` returns 0.
4. **App Store Server Notifications** (App Information → App Store Server Notifications): set both Production
   and Sandbox URLs to `https://www.skinstel.com/api/apple-notifications`, version 2.
5. App Privacy answers must match `Skintel/Resources/PrivacyInfo.xcprivacy`: email, name, user id, user content
   (products/journal), photos (label OCR, not retained), purchase history — all linked to identity, none used for tracking.
6. Sandbox tester account (Users and Access → Sandbox) for TestFlight purchase testing.

## 4. Supabase — Apple provider and migration

1. **Authentication → Providers → Apple**: enable. In *Authorized Client IDs* add `com.skintel.app` (the bundle id).
   The native flow uses `signInWithIdToken`; no Services ID or secret key is needed for it. (Keep any existing web
   Apple configuration as-is.)
2. **SQL editor**: run `supabase/migrations/0004_apple_iap.sql`. It adds `source`, `apple_original_transaction_id`,
   `apple_product_id` to `subscriptions` and the `founding_next_seat()` function. Without it `/api/apple-verify` fails.
3. Email templates: confirmation and password-reset links open the **web app** (Site URL). That is intended — the iOS
   sign-up flow tells the user to confirm from the email, then sign in.

## 5. Vercel — server environment

`npm install` already added `@apple/app-store-server-library` to `package.json`; redeploy after setting:

| Variable | Value | Consumed by |
|---|---|---|
| `APPLE_APP_APPLE_ID` | numeric app id from App Store Connect | `api/_apple.ts` (Production verifier) |
| `APPLE_BUNDLE_ID` | `com.skintel.app` (optional, this is the default) | `api/_apple.ts` |
| `APPLE_ENVIRONMENT` | leave unset (both Production and Sandbox are tried) | `api/_apple.ts` |

Apple's Root CA G3 is embedded in `api/_apple.ts` (and kept at `api/_apple/AppleRootCA-G3.cer`); nothing to configure.

## 6. Before submitting

- Detach the StoreKit configuration from the scheme's Run action (or archive — archives never use it).
- Run `/appstore-check` and `/ship-check` (Claude Code skills in `.claude/skills/`).
- Work through `APP_STORE_CHECKLIST.md`.
- Screenshots: 6.7" and 6.1" sets. The design previews in `designs/previews/` are not screenshots of the app.

## Things that intentionally are not set up

- **Google sign-in** — removed from the web app; would need a Google Cloud OAuth client and the Supabase Google provider. See `DESIGN_REVIEW.md`.
- **Push notifications / routine reminders** — not part of the product today.
- **Staging backend** — there is one Supabase project and one Vercel deployment. Debug builds talk to production;
  point `API_BASE_URL` at `vercel dev` in `Config/Debug.xcconfig` when working on API routes.
