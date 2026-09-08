# Design review — iOS implementation vs `designs/skintel-ios-designs.html`

The spec is the visual baseline. This file records where the app departs from it and why, so the departures are
decisions rather than drift. Anything under **Proposed** has *not* been implemented.

## Departures made because the shipped product disagrees with the spec

| Surface | Spec | App | Reason |
|---|---|---|---|
| Paywall (§16) | $29/yr, $59 anchor, "77 of 100 spots" | Founding **$20 once / 3 months / 500 seats**, Pro **$9/mo** and **$79/yr**, prices from StoreKit | `Discount.tsx`, `stripe-prices.ts` and the DB RPC are the product. The layout — kicker, serif headline, featured card with seat bar, benefits, dark CTA, Restore/Terms/Privacy — is the spec's. |
| Sign in (§06) | Apple · Google · magic link | **Apple · email + password** (with create account and reset) | The web is email/password; Google was removed; magic links have no in-app landing. Same accounts on web and iOS. |
| Journal (§14) | Worked · Unsure · Broke out | **Clear · Mild · Moderate · Broke out** | The `skin_journal.condition` CHECK constraint and `/api/journal` accept exactly these four. |
| Home stats (§07) | "Journal stats" | Product-outcome counts (total / good / unsure / bad) | That is what `Dashboard.tsx` computes; the labels Logged / Worked / Unsure / Broke out are kept. |
| Verdict (§10) | "confidence high" label | Omitted | `/api/scan-ai` returns no confidence field; inventing one would be a false signal. Flag count is shown instead. |
| Compare (§12) | Rows: Barrier · Fragrance · Comedogenic · Per 100 ml | Score ring, one-line verdict, ✓ wins / ✗ concerns | The compare endpoint returns `score/short/keyWins/keyConcerns`; there is no price-per-volume data anywhere in the product. |
| Culprits (§15) | Use→breakout timeline bars, "Pause product" / "Not it" | Per-product hit bars (which "broke out" products contain the ingredient), journal AI suspects with confidence and evidence dates | No per-day usage data exists; the local engine is co-occurrence. "Pause"/"Not it" imply a feedback loop the backend doesn't have. |
| Journal photo | Dashed "Photo" tile | Omitted | `photo_url` is a bare string with no upload path or storage bucket on the web either. |
| Settings (§17) | Routine reminders · Culprit alerts toggles | Only **Haptics** | No notification system exists in the product. Adding local reminders is a real feature, listed under Proposed. |
| Settings "Founding · $29/yr" chip | — | Tier chip from the `subscriptions` row; "Managed on skinstel.com" for Stripe-origin rows, App Store management sheet for Apple-origin rows | Apple's rules on external purchase links; Stripe subscribers keep managing on the web. |
| Widgets (§18) | Small + medium WidgetKit | Deferred | Not part of the shipped product. |

## Clear improvements applied (allowed by the brief without asking)

- **Scanner locked state** — the server returns 402 for free accounts on every scan route. Instead of a camera that
  silently fails, free users see why and get a working "add by hand" path plus the paywall.
- **Entitlement bug fix** — the web hook treats a cancelled Pro as paid; the app uses the server's status-aware rule,
  so it never promises a feature the API refuses.
- **Camera permission recovery** — denied state explains what still works and deep-links to Settings (spec had no denied state).
- **"Type it" sheet** — the web scanner's four tabs (paste / barcode / link / search) become one sheet with a segmented
  control, keeping the camera surface as clean as the spec.
- **Live INCI parse count** on the add/edit form, and an ingredient chip preview, so a bad paste is visible before saving.
- **Loading, empty, error and offline states** on every data screen (skeletons where a list will appear, so layout doesn't jump).
- **Destructive confirmations** — product delete, entry delete, sign out; account deletion requires typing DELETE.
- **Reduce Motion** honoured by the score ring, scan line, welcome cards and segmented control.
- **Dynamic Type** — every font token is registered `relativeTo` a text style; tap targets are ≥ 44pt.

## Proposed (subjective — not implemented)

| Proposal | Current behaviour | Change | Reason | Expected benefit |
|---|---|---|---|---|
| Dark mode | Light only, `UIUserInterfaceStyle = Light` | Design a dark palette (the scanner already establishes one) and drop the override | The spec is light-only; forcing light is honest to it but users on system dark get a bright app | Comfort at night, when the PM routine is used |
| Persist the skin profile server-side | `auth.users.user_metadata` | A `profiles` table with RLS, and pass `skin_type`/`concerns` to `/api/scan-ai` | The found sheet says "Matching against combination · breakout-prone", but the API personalises by culprits only | Verdicts that reflect the profile the onboarding collects |
| Persist scan verdicts server-side | On device (`ScanStore`), like the web's localStorage | `product_scans` table keyed by product | Scores vanish on reinstall or device change | Scores survive and sync across web and iOS |
| Routine reminders | None | Local `UNUserNotification` at a chosen AM/PM time | The spec shows the toggle; the routine card already knows the slot | The habit loop the journal streak depends on |
| Google sign-in | Not offered | Supabase Google provider + Google Cloud OAuth client (native SDK or `ASWebAuthenticationSession`) | Design lists it; web removed it | Lower friction for Android-migrating users |
| Founding expiry on the Stripe side | Stripe founding rows have `current_period_end = null` (never expire) | Webhook sets purchase + 3 months, as the Apple route does | The "three months" promise is only enforced for Apple purchases | Consistent entitlement across channels |
| Seat allocation in the Stripe webhook | `max(seat)+1` in application code | Call `founding_next_seat()` from `0004_apple_iap.sql` | Race-prone under concurrent checkouts | No duplicate-seat failures |
