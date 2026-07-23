# Skintel — iOS App Design Spec

Complete visual design for the Skintel iOS app (Capacitor build). Open
**`skintel-ios-designs.html`** in a browser to view the full spec: 17 surfaces
in iPhone 15 Pro frames with design notes under each one.

Rendered previews live in [`previews/`](previews/); the master app icon is
[`app-icon.svg`](app-icon.svg) (1024×1024, full-bleed — iOS applies the squircle mask).

## Surfaces

| # | Surface | Preview |
|---|---------|---------|
| 01 | App icon system (master, home, spotlight, settings, dark, tinted) | `previews/icon.png` |
| 02 | Splash | `previews/splash.png` |
| 03 | Onboarding 1 — value promise | `previews/ob1.png` |
| 04 | Onboarding 2 — skin profile | `previews/ob2.png` |
| 05 | Onboarding 3 — camera permission | `previews/ob3.png` |
| 06 | Sign in (Apple / Google / magic link) | `previews/login.png` |
| 07 | Home / Dashboard | `previews/home.png` |
| 08 | Scanner — viewfinder | `previews/scan.png` |
| 09 | Scanner — match & auto-analyze sheet | `previews/found.png` |
| 10 | Analysis — verdict | `previews/verdict.png` |
| 11 | Product detail — INCI list | `previews/product.png` |
| 12 | Compare | `previews/compare.png` |
| 13 | Routine (PM) with conflict alert | `previews/routine.png` |
| 14 | Journal | `previews/journal.png` |
| 15 | Culprits — suspect detection | `previews/culprits.png` |
| 16 | Paywall — founding member | `previews/paywall.png` |
| 17 | Settings | `previews/settings.png` |
| 18 | WidgetKit — small & medium | `previews/widgets.png` |

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

## Regenerating previews

Previews are shot from the HTML with Playwright (`deviceScaleFactor: 2`).
Install Instrument Serif, DM Sans and JetBrains Mono locally first so headless
Chromium doesn't fall back to system fonts, then screenshot each `#s-*` section
of `skintel-ios-designs.html`.
