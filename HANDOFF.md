# Skintel — handoff for a new coding agent

Read this first, then `CLAUDE.md` and `ios/Skintel/CLAUDE.md`. The repo is public:
https://github.com/pixelbuyte/Skintel — study it directly; everything below points into it.

Last updated 2026-09-28 (main at `e2550ec`).

---

## 1. What Skintel is

A skincare app that tells you whether a product suits *your* skin. You keep a **shelf** of products you
use and mark how your skin reacted (Worked / Unsure / Broke out). Skintel reads ingredient lists, gives a
**verdict** for each product, finds **Triggers** (ingredients your "broke out" products share), keeps a daily
**skin log** (check-ins), builds AM/PM **routines**, and has an AI chat, **Ask Skintel**, that answers from
your shelf, routine and check-ins.

- App name: **Skintel**. Paid plan: **Skintel+** (never "Pro", "Premium", "Upgrade").
- Website/API domain: **skinstel.com** (note the extra "s" — historic; the brand is Skintel).
  The mascot package is also spelled `SkinstelMascot` for the same reason. Don't "fix" either.
- Audience: mostly women, many dealing with sensitive or changing skin (including menopause).
  Tone: calm, honest, warm, never clinical, never hype.

## 2. Repo map

| Path | What |
|---|---|
| `ios/Skintel/` | **Native SwiftUI iOS app** — the product. Start here. |
| `ios/Skintel/Skintel/Features/` | One folder per area: Analysis (verdict), Auth, Compare, Home (Today), Journal, Onboarding, Products (shelf, Add product hub), Recommend (Ask Skintel), Routine, Scanner, Settings, Subscription (walls + plans), Triggers |
| `ios/Skintel/Skintel/DesignSystem/` | Tokens (`SKColor`, `SKFont`, spacing, radius, animation) and components (`SKHints`, `SKStates`, `SKNavigation`, …) |
| `ios/Skintel/SkintelCore/` | SwiftPM package: models, API client, pure logic (verdicts, streaks). Tests run on Linux. |
| `ios/Skintel/SkintelWidgets/` + `ios/Skintel/Shared/` | Home-screen widgets (Ask Skintel = medium, Shelf = small). `Shared/` is compiled into both targets; Foundation-only. |
| `ios/Packages/SkinstelMascot/` | The animated mascot ("the drop"). |
| `ios/Skintel/project.yml` | **XcodeGen spec** — the `.xcodeproj`, Info.plist and entitlements are generated from it. |
| `ios/App/` | **Legacy Capacitor wrapper. Do not build on it.** |
| `api/*.ts` | Vercel serverless API (the iOS app and web both call it). Files starting `_` are shared modules. |
| `src/` | React web app (skinstel.com). |
| `supabase/` | Database migrations. |
| `designs/` | Design spec (`skintel-ios-designs.html`), previews, app icon, App Store screenshots. |
| `codemagic.yaml` | iOS CI/CD. |
| Other docs | `IOS_ARCHITECTURE.md`, `IOS_SETUP.md`, `MIGRATION_MAP.md` (settled decisions), `DESIGN_REVIEW.md`, `APP_STORE_CHECKLIST.md` |

## 3. Stack

- **iOS:** SwiftUI, iOS 17+, Swift 6 with strict concurrency `complete`, StoreKit 2, Sign in with Apple,
  WidgetKit, AVFoundation scanner. Bundle `com.skintel.app`; widgets `com.skintel.app.widgets`;
  App Group `group.com.skintel.app`. iPhone only, portrait.
- **Web:** React 19, Vite, Tailwind 3, react-router 7, Stripe (web purchases only). Hosted on Vercel.
- **Backend:** Supabase (Postgres + Auth + Row Level Security). The anon key in
  `ios/Skintel/Config/Config.example.xcconfig` is public by design — don't "fix" it.
- **API:** Vercel functions in `api/`. Server secrets (Supabase service role, Stripe, AI keys, Apple) live in
  Vercel env config only. Never commit a secret.

## 4. AI models (all server-side, in `api/`)

- `api/_ai.ts` is the one router for scans. **OpenRouter first**, trying in order
  `google/gemini-3.1-flash-lite` then `openai/gpt-5.6-luna` (`SCAN_MODELS`). If OpenRouter is not configured
  or fails, it falls back to Anthropic directly with `claude-haiku-4-5-20251001`.
- Used by: barcode lookup (`_barcode-lookup.ts`, with web search), photo/label reading (`_scan-photo-bulk.ts`),
  Compare (`_compare.ts`).
- **Ask Skintel** (`_assistant.ts`) has two user-selectable tiers, shown in the app as a slide toggle:
  - **Luna** — `openai/gpt-5.6-luna` (fallback `google/gemini-3.1-flash-lite`), low reasoning, fast.
  - **Sol** — `anthropic/claude-haiku-4.5` via OpenRouter (fallback Luna), longer and more careful.
- Link import (`_import-url.ts`) and journal analysis (`_journal-analyze.ts`) call Anthropic directly
  (`claude-haiku-4-5-20251001`).
- Honesty rule: **verdicts do not use skin type or age** — only Ask Skintel does. Never write copy that says
  otherwise.

## 5. Plans and entitlement

- **Free:** shelf of 5 products, daily check-ins, routines, verdicts on typed-in products, tips.
- **Skintel+:** scanning (barcode, photo of label, product link), Ask Skintel, Insights, Compare, Triggers,
  routine conflict checks, Picks, unlimited shelf.
- StoreKit product ids (must match `api/_apple.ts`): `com.skintel.app.pro.monthly`,
  `com.skintel.app.pro.yearly`, `com.skintel.app.founding` (non-renewing, 3 months).
  Prices always come from StoreKit `displayPrice` — never hard-code.
- Web founding offer: $20 for 3 months (was $49.99), sold through Stripe on skinstel.com only. The iOS app
  must never link to web checkout (App Review).
- **Entitlement is decided by the server** (`/api/apple-verify`, Supabase `subscriptions`). Never grant
  Skintel+ on the client. Gates: free users hitting a Skintel+ feature see a **full-screen wall**
  (`ProLockedView`, "Get Skintel+" / "Maybe later"), then the plans page (`PaywallView`).

## 6. Design system

**Colors** (`DesignSystem/Tokens/SKColor.swift`):

| Token | Hex | Use |
|---|---|---|
| `bg` | `#F4EDE0` | page background (warm cream) |
| `cream` | `#FFFEFA` | cards |
| `primary` | `#A35848` | terracotta — buttons, accents, brand |
| `primaryPressed` | `#8E4538` | pressed state |
| `ink` | `#1A1814` | text |
| `muted` | `#6B6760` | secondary text |
| `line` | `#EAE6DF` | hairlines |
| `goodBg` / `goodFg` | `#EEF2DD` / `#5C7A4F` | sage — good, done |
| `cautionBg` / `cautionFg` | `#F5E6DC` / `#743C2B` | clay — caution |
| `badBg` / `badFg` | `#FDEAEA` / `#B22B2B` | bad |
| `scannerBg` | `#0B0A08` | camera screens |

- **No yellow / honey / gold.** The founder dislikes it; caution is clay brown.
- **Fonts** (bundled, `SKFont.swift`): **Instrument Serif** for titles and hero text, **DM Sans** for
  body and buttons, **JetBrains Mono** for small uppercase labels and ingredient data. Always use the
  `SKFont` tokens so Dynamic Type works.
- **Mascot:** "the drop", a terracotta water-drop character. Animated via
  `SKMascot(action:height:isPlaying:settleAfter:)` with actions `.idle .wave .walk .serum .scan .thinking
  .celebrate .sleep`. Still illustrations via `SKDrop("<asset>", size:)`: `DropIngredients DropInsights
  DropWarning DropCompare DropSunscreen DropRoutineDone DropNight DropScanner DropPrivacy DropAsk
  DropRoutineBuilder DropCheckIn`. Rules: decorative only, **one drop per screen**, never beside the
  animated mascot, celebrate only after a real success.
- **Copy rules:** CTA is always "Get Skintel+". Say **Triggers**, never "culprits". No emoji in UI. No fake
  progress, no invented stats, no claims the server doesn't back. Not medical advice — cosmetic language only.
- **Accessibility:** Dynamic Type via `SKFont`, Reduce Motion respected, 44pt tap targets, decorative art
  hidden from VoiceOver. On iOS 26, glass-styled buttons need `.contentShape(...)` or only the icon is
  tappable (this caused real bugs).
- Design canvases live in private claude.ai artifacts the founder can share as screenshots; the in-repo
  spec is `designs/skintel-ios-designs.html`.

## 7. The rules that matter most

1. **The founder has no Mac.** Nothing is compiled locally. The only compiler is **Codemagic `ios-ci`**
   (~6–10 min). Check every type, member, initializer label and modifier against the real declarations in
   this repo before committing. Don't write Swift from memory.
2. **Touch only what you were asked to.** No drive-by refactors, renames or restyles — a past change broke
   an animation nobody asked to touch.
3. Swift 6 strict concurrency: no mutable `static var`; watch `Sendable`.
4. `SkintelCore` declares its own `Product` — files that import StoreKit must write `StoreKit.Product` /
   `StoreKit.Transaction`.
5. Persisted models: any new field must be optional/defaulted, or users lose data on update. Update every
   initializer call site, tests included.
6. Adding or removing Swift files needs the Xcode project regenerated from `project.yml` with XcodeGen.
   If you can't run XcodeGen, say so in the PR — don't hand-edit `project.pbxproj`.
7. Never commit secrets. Never grant Skintel+ client-side. Never add a web-purchase link in the app.
8. Don't touch `codemagic.yaml`, StoreKit ids or `Config.example.xcconfig` unless that is the task.

## 8. How work ships

1. Branch from `main` (e.g. `claude/<topic>` or `cursor/<topic>`). One topic per branch.
2. Push, then run **Codemagic `ios-ci`** on the branch (simulator build + SkintelTests + SkintelUITests +
   SkintelCore tests). Iterate until green. `SkintelCore` tests also run anywhere with
   `cd ios/Skintel/SkintelCore && swift test`.
3. Open a PR to `main`. The founder reviews and merges. Vercel deploys the web/API on merge.
4. **TestFlight:** the founder starts Codemagic **`ios-release`** from `main`. It signs (app + widget
   profiles), sets the build number from App Store Connect, and uploads to TestFlight **internal testing
   only** — it never submits to App Review or the App Store. Agents do not start `ios-release`.

## 9. Where things stand (2026-09-28)

- Recently shipped: full-screen Skintel+ walls, Add a product hub (scan / photo / link / type), streak card
  and Today checklist, sample shelf, one-time tips, Culprits → Triggers, Home-screen widgets, widget signing
  in CI.
- **Open PR #49:** tester bug fixes (scanner button taps, Ask wall shown to members, Luna/Sol slide, "Show
  examples", free-user tips, faster barcode lookup). Green on CI, waiting to merge.
- **App Review (build 21)** — known gaps to fix:
  - No in-app disclosure/consent before Ask Skintel sends personal data to third-party AI (guideline 5.1.2(i)).
  - Privacy policy (`src/pages/Privacy.tsx`) names Anthropic only; it must also name OpenRouter, Google and
    OpenAI, and stop saying no health data is collected (check-ins store symptoms).
  - Account deletion (`api/account.ts`) doesn't revoke the Sign in with Apple token (5.1.1(v)); needs a
    Sign in with Apple key in Vercel env.
  - Privacy manifest should list health (symptoms) and age range.
  - Remove "14-day refund via Apple" from the founding plan copy; reword "Verdict for your skin".

## 10. Backlog (not built yet)

Features:
- Onboarding: add the trial / founding-deal step.
- Skintel+ wall: a second, switchable style — the real feature visible behind, upgrade panel over the bottom.
- Add product → plans page: scan, photo and link each show their own visual (today all show the same bottle).
- Routine "Set up": with 5 or fewer shelf products, offer "Get recommendations from Ask Skintel" or
  "Scan more products"; with more, go straight in.
- Widgets: Large (shelf grid) and Extra Large sizes.

Design first, then build:
- Onboarding step 4/4 scan illustration and animation (current bottle art is weak).
- Streak rewards: the mascot unlocks accessories/skins at streak milestones; tapping it makes it react.
- Referral: the referrer gets something immediately (e.g. 50% off next month) — check what StoreKit offer
  codes / promotional offers allow first.
- In-app announcement pop-up for launches (like a new-model announcement).

## 11. Useful project skills

`.claude/skills/` has reusable audit playbooks any agent can read: `advisor`, `appstore-check`,
`design-review`, `ios-audit`, `qa`, `security-review`, `ship-check`.
