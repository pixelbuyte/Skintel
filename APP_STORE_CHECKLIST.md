# App Store checklist

Status legend: ✅ done in code · 🔧 needs an external step (see `IOS_SETUP.md`) · ⚠️ known gap, decided.

| Area | Status | Evidence |
|---|---|---|
| App icon 1024 | ✅ | `Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png` (from the Capacitor project, master `designs/app-icon.svg`) |
| Display name / bundle id | ✅ | `Skintel` / `com.skintel.app` in `project.yml` |
| Version / build | ✅ | `MARKETING_VERSION 1.0.0`, `CURRENT_PROJECT_VERSION 1` |
| Launch | ✅ | `UILaunchScreen` cream background → SwiftUI splash → Keychain restore; no sign-in flash |
| Orientation | ✅ | Portrait only, iPhone only (`TARGETED_DEVICE_FAMILY 1`) |
| Permission strings | ✅ | Camera and Photo Library descriptions are specific to barcode/label use |
| Camera asked in context | ✅ | Onboarding step 3 and the scanner; denied state links to Settings |
| Entitlements | ✅ | Sign in with Apple (generated from `project.yml`) |
| Privacy manifest | ✅ | `PrivacyInfo.xcprivacy`: no tracking; email, name, user id, user content, photos (OCR), purchase history; UserDefaults CA92.1 |
| App Privacy answers | 🔧 | Must match the manifest when filling in App Store Connect |
| Sign in with Apple | ✅ / 🔧 | Native `SignInWithAppleButton` + nonce; Supabase Apple provider needs `com.skintel.app` in client ids |
| Account deletion in-app | ✅ | Settings → Delete account → type DELETE → `/api/delete-account` → local sign-out |
| Restore purchases | ✅ | Paywall footer and Settings → `AppStore.sync()` + `currentEntitlements` → backend verify |
| StoreKit products | 🔧 | Create the three products in App Store Connect (`IOS_SETUP.md` §3) |
| Prices from the store | ✅ | `Product.displayPrice` everywhere; nothing hard-coded |
| Subscription disclosures | ✅ | Renewal terms under the CTA; non-renewing founding explains "never renews" |
| No external purchase links | ✅ | No Stripe checkout, `/pricing` or `/discount` links in the app; Stripe subscribers see "Managed on skinstel.com" text only |
| Server receipt verification | ✅ / 🔧 | `api/_apple.ts` + Apple Root CA G3; needs `APPLE_APP_APPLE_ID` env and migration `0004` |
| Server notifications | 🔧 | Register `https://www.skinstel.com/api/apple-notifications` (Production + Sandbox) |
| Terms / Privacy URLs | ✅ | `https://www.skinstel.com/terms`, `/privacy` on the paywall and in Settings |
| Production API URLs | ✅ | `Config/Base.xcconfig` → skinstel.com; no localhost in Release |
| Secret handling | ✅ | Only the public anon key ships; Stripe/Anthropic/service-role keys are server-only |
| Crash-free launch without config | ✅ | Missing config shows `ConfigErrorView` instead of crashing |
| Offline behaviour | ✅ | Stale session kept; stores keep last data; `APIError.offline` surfaces with retry |
| Loading / empty / error states | ✅ | Every data screen (`SKSkeleton`, `SKEmptyState`, `SKErrorState`) |
| Accessibility | ✅ | Labels/traits on custom controls, Dynamic Type via `relativeTo`, Reduce Motion honoured, ≥44pt targets |
| Medical claims | ✅ | "Not medical advice. Patterns, not prescriptions." in Settings; verdict copy is cosmetic |
| Placeholder content | ✅ | None; demo data exists only in the welcome illustration, clearly decorative |
| Debug content in Release | ✅ | Network logging compiled out (`#if DEBUG`); StoreKit config is a scheme-level Run option only |
| Release build succeeds | 🔧 | Must be run on a Mac (`/qa`); this repository was authored without Xcode available |
| Founding "3 months" for Stripe purchases | ⚠️ | Stripe webhook writes no expiry; Apple path does. Listed in `DESIGN_REVIEW.md` Proposed |
| Screenshots / metadata | 🔧 | Capture from the running app; design previews are not screenshots |
