# Skintel — App Store listing (build 47)

Paste into App Store Connect → Skintel → iOS App → the version → each field. Character counts are
checked against Apple's limits. Prices are never written here: they come from StoreKit.

## Screenshots

`out/01-verdict.png` … `out/05-scan.png`, 1290 × 2796. Upload them to the **6.9" iPhone** slot in
this order; Apple scales them for smaller iPhones. The first three show in search results.

Slides 1–4 show the app in use with example data: a scan verdict, a Triggers result, a stocked
routine and an Ask answer. Each one is rebuilt in `slides.html` from its SwiftUI view (VerdictView,
TriggersView, HomeView, RecommendView), using the same fonts, sizes and colours. The tab bar and
composer are cropped from real build-47 captures in `raw/`. Slide 5 is a real capture. Product
names are generic on purpose: no real brands, to avoid trademark trouble in review.

To refresh: edit the copy or example data in `slides.html` (or swap a capture in `raw/`), then run
`python3 marketing/app-store/render.py` from the repo root.

## Name (30) — 7

```
Skintel
```

## Subtitle (30) — 29

```
Know what works for your skin
```

## Promotional text (170) — 145

Can be changed any time without a new build.

```
Scan a product, log how your skin reacted, and let Skintel find the ingredient your bad days have in common. Ask anything about your own routine.
```

## Keywords (100) — 97

Comma-separated, no spaces. Leaves out words already in the name and subtitle (Apple indexes those).

```
skincare,ingredients,scanner,routine,breakout,acne,sensitive,trigger,barcode,inci,retinol,journal
```

## Description (4000)

```
Skintel tells you whether a product suits your skin, not skin in general.

Keep a shelf of what you use, mark how your skin reacted, and Skintel reads the ingredient lists to find what your bad days have in common.

ADD WHAT YOU USE
Scan the barcode, snap the ingredient list, paste a product link or type the name. Skintel reads the ingredients and gives a verdict for your skin type and concerns.

YOUR ROUTINE, IN ORDER
Build your morning and evening routine. Skintel puts your products in order and flags pairs that shouldn't be mixed, like strong actives on the same night.

FIND YOUR TRIGGERS
Mark products as Worked, Unsure or Broke out. When two or more broke you out, Skintel shows the ingredients they share, so you know what to look for on the next label.

A MINUTE A DAY
Check in on how your skin feels. Your streak, a seven-day view and journal patterns line your check-ins up with when each product joined your shelf. Insights get sharper after about a week.

ASK SKINTEL
Ask about your routine, an ingredient or a reaction. Answers use your shelf, your routine and your check-ins. Choose Luna for quick everyday questions or Sol for deeper ones.

WIDGETS
Keep your streak and today's routine on your Home Screen.

FREE
A shelf of up to 5 products, daily check-ins, routines, verdicts on products you type in, and tips.

SKINTEL+
Scanning (barcode, ingredient photo and product link), Ask Skintel, Insights, Triggers, Compare, routine conflict checks, Picks and an unlimited shelf.

Skintel+ is available as a monthly or yearly auto-renewing subscription, or a one-time 3-month pass. Payment is charged to your Apple Account at confirmation. Subscriptions renew automatically unless cancelled at least 24 hours before the end of the current period. Manage or cancel in Settings → your name → Subscriptions.

Skintel is not medical advice. It shows patterns, not diagnoses. See a dermatologist for persistent or severe skin problems.

Privacy: https://skinstel.com/privacy
Terms: https://skinstel.com/terms
```

## What's New (4000)

```
Welcome to Skintel. Scan your products, log how your skin reacts, and find your triggers.
```

## Other fields

| Field | Value |
|---|---|
| Category | Primary: Health & Fitness · Secondary: Lifestyle |
| Age rating | 4+ (no objectionable content; answer the questionnaire "None" throughout) |
| Support URL | `https://skinstel.com` (there is no `/support` page yet) |
| Marketing URL | `https://skinstel.com` |
| Privacy Policy URL | `https://skinstel.com/privacy` |
| Copyright | `2026 <legal name>` — founder fills in |

## Before you paste

- **Description must match the build.** Every feature above is listed as shipped in `HANDOFF.md` §5/§9.
  If Compare, Picks or the product-link import aren't in build 47, delete them from the description.
- **Privacy policy.** `HANDOFF.md` §9 says it still names only Anthropic. Make sure it names every AI
  provider and covers check-in symptoms before the listing goes live.
- **Mock screens must stay true to the app.** App Review (2.3.3) wants screenshots that show the app
  in use. If one of these screens changes in a later build, update its mock in `slides.html` to match.
