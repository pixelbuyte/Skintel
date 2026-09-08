---
name: appstore-check
description: Review the Skintel iOS project the way App Review will — StoreKit 2, subscriptions, restore, Sign in with Apple, account deletion, privacy policy/terms, privacy manifest, permission strings, camera/photo usage, misleading claims, unfinished screens, debug content, external purchase links, release configuration. Returns PASS/WARNING/FAIL per area and fixes implementation FAILs.
---

# /appstore-check

Use `APP_STORE_CHECKLIST.md` as the checklist and update its status column. For each area return
**PASS / WARNING / FAIL** with evidence:

- **Purchases** — StoreKit 2 only; prices from `displayPrice`; renewal terms stated; Restore visible on the paywall and in Settings;
  no link to Stripe checkout anywhere in the app (grep `stripe-checkout`, `skinstel.com/discount`, `/pricing`).
- **Sign in with Apple** — offered wherever another sign-in method is; native `SignInWithAppleButton`; entitlement present.
- **Account deletion** — reachable from Settings, in-app, completes without email support.
- **Legal** — Terms and Privacy links on the paywall and in Settings resolve to live pages.
- **Permissions** — `NSCameraUsageDescription` / `NSPhotoLibraryUsageDescription` specific and truthful; asked in context.
- **Privacy manifest** — present, required-reason APIs match usage, collected data matches App Privacy answers.
- **Completeness** — no placeholder copy, no "coming soon", every button does something, every screen has states.
- **Claims** — no medical/diagnostic language; "not medical advice" present.
- **Debug** — no dev URLs in Release (`Config/Release.xcconfig`), no debug menus, `ITSAppUsesNonExemptEncryption=false`.
- **Metadata** — bundle id `com.skintel.app`, version/build set, icon 1024, portrait-only, category.

Fix any FAIL that is an implementation issue you can resolve directly; list external setup FAILs (App Store Connect
products, Supabase Apple provider, Server Notifications URL) with the exact step from `IOS_SETUP.md`.
