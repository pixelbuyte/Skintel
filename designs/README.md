# Skintel — iOS App Design Spec

Complete visual design for the Skintel iOS app (Capacitor build). Open
**`skintel-ios-designs.html`** in a browser to view the full spec: 17 surfaces
in iPhone 15 Pro frames with design notes under each one.

Rendered previews live in [`previews/`](previews/). The brand mark is the
**Skintel star** — [`public/icons/skintel.svg`](../public/icons/skintel.svg) is the
source of truth; [`app-icon.svg`](app-icon.svg) is the full-bleed 1024×1024 iOS
master built from the same geometry (iOS applies the squircle mask).

## Surfaces

| # | Surface | Preview |
|---|---------|---------|
| 01 | Splash | `previews/splash.png` |
| 02 | Onboarding 1 — value promise | `previews/ob1.png` |
| 03 | Onboarding 2 — skin profile | `previews/ob2.png` |
| 04 | Onboarding 3 — camera permission | `previews/ob3.png` |
| 05 | Sign in (Apple / Google / magic link) | `previews/login.png` |
| 06 | Home / Dashboard — A: stat grid | `previews/home.png` |
| 06b | Home / Dashboard — B: skin-score ring | `previews/home-b.png` |
| 06c | Home / Dashboard — C: Whoop / Apple Health style (light) | `previews/home-c.png` |
| 06d | Home / Dashboard — D: dark, true Whoop | `previews/home-d.png` |
| 06e | Home / Dashboard — E: editorial minimal | `previews/home-e.png` |
| 06f | Home / Dashboard — F: bento grid | `previews/home-f.png` |
| 06g | Home / Dashboard — G: timeline / agenda | `previews/home-g.png` |
| 07 | Scanner — viewfinder | `previews/scan.png` |
| 08 | Scanner — match & auto-analyze sheet | `previews/found.png` |
| 09 | Analysis — verdict | `previews/verdict.png` |
| 10 | Product detail — INCI list | `previews/product.png` |
| 11 | Compare | `previews/compare.png` |
| 12 | Routine (PM) with conflict alert | `previews/routine.png` |
| 13 | Journal | `previews/journal.png` |
| 14 | Triggers — what actually breaks you out | `previews/triggers.png` |
| 15 | Paywall — launch pricing ($8.99/mo · $79/yr) | `previews/paywall.png` |
| 16 | Settings — A: current (profile, membership, preferences, data) | `previews/settings.png` |
| 16b | Settings — B: full app settings (adds notifications, appearance, support, delete account) | `previews/settings-b.png` + `previews/settings-b-bottom.png` |
| 17 | WidgetKit — small & medium | `previews/widgets.png` |

## Naming

The correlation feature is called **Triggers**, never "culprits" or "suspects" —
it matches the language already used on the marketing site ("find my triggers",
"your personal triggers"). Keep that consistent in copy and code.

## Design system

Tokens mirror `tailwind.config.ts` so the designs translate 1:1 into the
existing codebase:

- **Color** — bg `#F4EDE0`, card `#FFFEFA`, primary `#A35848` (hover `#8E4538`),
  ink `#1A1814`, muted `#6B6760`, border `#EAE6DF`
- **Verdict tones** — good `#5C7A4F` on `#EEF2DD`, caution `#8B6914` on `#FFF4E0`,
  bad `#B22B2B` on `#FDEAEA`
- **Type** — Instrument Serif (display), DM Sans (UI), JetBrains Mono (data:
  barcodes, INCI names, confidence %, section labels)
- **Shape & motion** — 16px card radius, `cubic-bezier(0.32, 0.72, 0, 1)` iOS easing,
  breathe/rise-in animations as defined in Tailwind config

### Motion

The spec animates live in the browser. Four named loops, all on iOS easing and all
disabled under `prefers-reduced-motion`:

| Class | Used on | Behaviour |
|-------|---------|-----------|
| `.anim-scan` | scanner, onboarding 3 | scan line sweeps the capture window, 2.4s |
| `.anim-mark` | splash | star rises + settles, 0.6s, once |
| `.anim-sparkle` | splash star, scanner status dot | slow pulse, 2.8s |
| `.anim-ring` | verdict score | ring draws to the score, 1.1s, once |

Screenshots add `body.freeze`, which parks each loop on a representative frame
(negative `animation-delay` + `paused`) so stills are deterministic rather than
catching frame 0.

## Regenerating previews

Previews are shot from the HTML with Playwright (`deviceScaleFactor: 2`).
Install Instrument Serif, DM Sans and JetBrains Mono locally first so headless
Chromium doesn't fall back to system fonts, then screenshot each `#s-*` section
of `skintel-ios-designs.html`.
