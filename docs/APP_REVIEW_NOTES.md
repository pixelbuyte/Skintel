# App Review notes — read before touching subscriptions, privacy or metadata

Lessons from Skintel's App Review rejections. Apple's own wording is quoted; the founder
reports what App Store Connect (ASC) shows, because agents cannot see ASC. Never claim ASC state.

## Rejection of 2 Oct 2026 (build 1.0.0, reviewed on iPad Air 11-inch M3)

Apple's message followed an earlier rejection (26 Sep) and said "the issues we previously
identified still need your attention". Guidelines cited:

| Guideline | What Apple said | Who fixes it |
|---|---|---|
| 2.1(b) App Completeness | "In-App Purchase products have not been submitted for review. The app includes references to Pro but the associated In-App Purchase products have not been submitted." Fix: submit the IAPs **and** upload a new binary. An App Review screenshot is required to submit an IAP. | Founder in ASC (Monetization > Subscriptions / In-App Purchases), then a new build |
| 3.1.2(c) Subscriptions | Missing in the metadata: functional link to the Terms of Use (EULA). The app must show title, length, price (and price per unit) and functional Terms + Privacy links. Privacy Policy URL goes in the Privacy Policy field; EULA in the App Description (standard Apple EULA link) or the EULA field. Reply with a screen recording and put the info in App Review Information > Notes. | Founder in ASC; the app already links Terms and Privacy on the paywall (`PaywallView.swift`) |
| 2.3.8 Accurate Metadata | Body text not captured yet. | TBD, get the text |
| 5.1.1 Data Collection and Storage | Body text not captured yet. | TBD, get the text |

Open items from earlier handoffs that likely overlap 5.1.1 / 5.1.2: privacy policy
(`src/pages/Privacy.tsx`) names only Anthropic and says no health data is collected, but
check-ins store symptoms and Ask Skintel uses OpenRouter, Google and OpenAI; no in-app consent
before sending personal data to AI; account deletion doesn't revoke the Sign in with Apple token
(needs the founder's `.p8` key in Vercel); `PrivacyInfo.xcprivacy` should list health + age range.

## Code fixes made after the 2 Oct rejection (PR #56)

- Privacy policy and Terms (`src/pages/Privacy.tsx`, `Terms.tsx`): names OpenRouter, Google, OpenAI and Anthropic;
  new section 3a says exactly what Ask Skintel and journal analysis send; health-related check-ins are no longer
  described as "not collected"; "Pro" is now Skintel+.
- In-app consent (`AIConsent` / `AIConsentSheet` in `RecommendView.swift`): asked once before the first typed Ask
  Skintel question or journal analysis; a toggle in Settings > Personalization withdraws it. Suggested questions and
  label scans don't need it (they send nothing personal).
- `PrivacyInfo.xcprivacy`: added Health (check-ins) and Other Data Types (age range).
- Paywall and onboarding copy: removed "14-day refund via Apple"; "Verdict for your skin" is now "Ingredient verdict".
- The "Upgrade screen style" picker is `#if DEBUG` only. `isTestBuild` is also true for App Review (sandbox), so it
  must not ship in a release build.
- The paywall already shows plan title, length, StoreKit price and Terms/Privacy links.
- NOT done: revoking the Sign in with Apple token on account deletion (5.1.1(v)). Apple needs an authorization
  code exchanged for a token, which the Supabase id-token sign-in doesn't keep, so it needs a re-authorize step at
  deletion plus the founder's `.p8` key in Vercel. Design it first; don't write it blind.
- Not compiled: there is no Swift toolchain in the agent environment. Confirm with Codemagic `ios-ci`.

Founder still does in ASC: App Privacy answers must match the manifest (Health, Other Data Types, plus the existing
types, all "linked to you", not used for tracking); subscriptions Ready to Submit and attached to the version;
group display name and app name spelled "Skintel"; EULA link in the description; Privacy Policy URL.

## Rules that would have prevented this

1. **IAP products ship with the version.** Create every product with its exact id
   (`com.skintel.app.pro.monthly`, `.pro.yearly`; see `api/_apple.ts`), price, localization and a
   review screenshot, then attach it on the version page. Product ids are permanent; the spelling is s-k-i-n-t-e-l.
2. **Never write "Pro" or "Premium" in anything Apple or a customer can see.** The plan is
   **Skintel+**. Product reference names, display names and group names included.
3. **Subscription disclosure lives in the app, the description and the privacy field.** Title, length,
   price, Terms link, Privacy link on the paywall; EULA link in the description; Privacy Policy URL set.
4. **App Privacy answers and the privacy policy must match what the code actually does**
   (health data, age range, third-party AI providers). Update them in the same change as the feature.
5. **Put a reviewer test account with Skintel+ and plain-language notes in App Review Information.**
6. **A fix needs a new binary** when Apple says so: PR, green `ios-ci`, then the founder starts `ios-release`.
   Agents never start `ios-release`.

## ASC navigation (founder)

- Subscriptions and IAPs: left sidebar > **Monetization** > Subscriptions / In-App Purchases.
- Privacy answers: **Trust & Safety** > App Privacy.
- Privacy Policy URL, description, EULA, App Review Information (Notes, test account): the app's version page.
- Offer codes for the welcome wheel: `scripts/asc/README.md`.
