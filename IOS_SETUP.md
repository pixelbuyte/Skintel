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

### Sign in with Apple account deletion

Native sign-in with an ID token does not give Supabase an Apple refresh token to revoke.
Account deletion therefore asks the user to confirm with Apple again, sends that fresh
authorization code and nonce to the authenticated server, and exchanges and revokes the
Apple token **before** deleting the Supabase account. Tokens are not stored or logged.

1. Apple Developer → Certificates, Identifiers & Profiles → Keys: create a key with
   **Sign in with Apple** enabled and configure its primary App ID as `com.skintel.app`.
   Keep the downloaded `.p8` key private. This is a Sign in with Apple key, not the
   App Store Connect key used for signing builds or verifying purchases.
2. Vercel → Skintel project → Settings → Environment Variables: configure these
   server-only variables for Production and the preview used for testing:

   | Variable | Value |
   |---|---|
   | `APPLE_SIGN_IN_TEAM_ID` | Apple Developer team ID |
   | `APPLE_SIGN_IN_KEY_ID` | Sign in with Apple key ID |
   | `APPLE_SIGN_IN_PRIVATE_KEY` | Complete `.p8` PEM; real newlines or escaped `\n` are accepted |

   The native client ID is fixed to `com.skintel.app`. No private key belongs in an
   iOS config file, the browser bundle, git, or chat. Redeploy the API after configuring
   its variables so the deployment has the current values.
3. Test using a disposable Apple-linked account in the iOS app: You → Account & data
   → Delete account → type DELETE → confirm with the same Apple account. Verify the
   account and its products, ingredients, journal and subscription record are gone,
   and Apple no longer lists Skintel under Sign in with Apple.
4. Test Cancel, a different Apple account, an expired confirmation and an Apple outage.
   Each must preserve the account and its data. Also test an email-only account:
   it deletes without an Apple prompt or Apple key.

Without the key, Apple-linked deletion reports temporarily unavailable and deletes
nothing. Older clients cannot bypass revocation. Apple-linked accounts deleting from
the web are directed to the iOS flow; email-only web deletion remains available.
Deletion does not cancel App Store billing; the existing separate cancellation notice
remains in place. The database's `ON DELETE CASCADE` constraints perform the account
data deletion atomically with the auth user (`supabase/schema.sql` and
`supabase/migration_journal.sql`). No database migration is required.

Offline API verification: `npm run test:account` compiles the API with strict TypeScript
and tests Apple/Supabase requests using mocks; it never deletes a real account.

## 6. Before submitting

- Detach the StoreKit configuration from the scheme's Run action (or archive — archives never use it).
- Run `/appstore-check` and `/ship-check` (Claude Code skills in `.claude/skills/`).
- Work through `APP_STORE_CHECKLIST.md`.
- Screenshots: 6.7" and 6.1" sets. The design previews in `designs/previews/` are not screenshots of the app.
- For the current rejection, read the full 2.3.8 and 5.1.1 Messages and the attached
  screenshots before resubmitting; titles alone do not establish that a fix is sufficient.
- Submit all three purchase products with review screenshots, and populate App Store
  Connect's Privacy Policy URL plus the App Description's Terms of Use link (or custom
  EULA). In-app legal links do not populate those metadata fields.
- Release from `main` only after `ios-ci` is green. Build 42 predates PR #62's privacy
  and paywall changes; use a new build containing that merge and the deletion fix.
  Build numbers are assigned by the release workflow, never hard-coded in source.

## Things that intentionally are not set up

- **Google sign-in** — removed from the web app; would need a Google Cloud OAuth client and the Supabase Google provider. See `DESIGN_REVIEW.md`.
- **Push notifications / routine reminders** — not part of the product today.
- **Staging backend** — there is one Supabase project and one Vercel deployment. Debug builds talk to production;
  point `API_BASE_URL` at `vercel dev` in `Config/Debug.xcconfig` when working on API routes.
