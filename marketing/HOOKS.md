# Skintel reaction hooks — research, hook bank, kit

The reference you sent is **Fastlane** (usefastlane.ai), a tool that makes "AI UGC" for apps. Its
signature format is the one the calorie apps (Cal AI, BitePal) won with:

1. **Reaction hook, 1–2 s.** A face reacting (hand over mouth, wide eyes) + one line of white text.
   Usually silent; the sound is a trending audio added in the app.
2. **Hand-held demo.** The app on a phone, doing its one thing (scan → result).
3. **Next hook.** Same demo, new hook. They test 3–5 hooks per demo and keep whichever holds viewers
   past 3 seconds.

## What the research says

| Finding | Source |
|---|---|
| The 6 calorie-app ads that ran 30+ days (out of 188 sampled) were all reaction + demo, from Cal AI and BitePal | [DanSUGC — UGC hooks for TikTok ads](https://dansugc.com/blog/ugc-hooks-tiktok-ads-formulas) (vendor sample, directional) |
| Text-overlay + reaction hooks work best at **1–2 s**; land the interrupt before the 2-second mark; a **2–5 word** text hook in the first frame, because ~40% scroll with sound off | same |
| Make 3–5 hooks on the same body; kill any with a 3-second view rate under ~20% | [AI UGC playbook 2026](https://www.absolutelyai.com.au/news/ai-ugc-style-video-ads-paid-social), [Flowjam](https://www.flowjam.com/blog/how-to-make-a-tiktok-ad-with-ai-2026) |
| Cal AI grew mainly through many creators posting short "scan my food" clips, not one big influencer | [Virlo — Cal AI breakdown](https://signal.virlo.ai/p/cal-ai-myfitnesspal-acquisition-growth-breakdown) |
| Skincare-scanner hooks that recur: "POV: you finally found the app that checks your skincare before you spend another $90", "this is your sign to ditch [other app]", "my derm made me throw out my shelf except these 3" | [TikTok discover: ingredient checker apps](https://www.tiktok.com/discover/skin-care-ingredient-checker-app), [Hook Mafia examples](https://www.hookmafia.io/tiktok-hook-examples) |
| Phone-native, unpolished footage out-engages polished production | [Hook Mafia](https://www.hookmafia.io/tiktok-hook-examples) |

All of these are marketing sources, not platform data. Treat them as patterns to test, not laws.

## The one change we make: no fake faces

Fastlane's hooks use **AI actors** presented as real users ("3 years in the gym and NOW I find
this??"). For us that would be a made-up testimonial: the FTC's 2024 rule on fake reviews covers
testimonials from people who don't exist or didn't have the experience, and Meta/TikTok ad policies
ban misleading endorsements. So:

- **Finished videos** (in `marketing/video/out/hook-*.mp4`) use the **teardrop mascot** as the one
  reacting. It's a cartoon brand character, so nobody reads it as a customer review.
- **The kit** lets *you* (or a real user who agrees) film the 2-second reaction. First-person lines
  ("I", "me", "my") are only for someone they're true for.

## Hook bank

Text ≤ 9 words, sentence case, one emotion. Paired with the demo body that pays it off.

| # | Hook text | Pays off with | Who can say it |
|---|---|---|---|
| 1 | 2 years of breakouts and NOW I find this?? | Triggers | mascot, or you if true |
| 2 | wait… my retinol and my toner were FIGHTING?? | Conflicts | anyone |
| 3 | I scanned my whole shelf and I'm not okay | Scan | mascot, or you after doing it |
| 4 | why did nobody tell me this app existed | Scan | anyone |
| 5 | the app just told me what keeps breaking me out | Triggers | mascot, or you if true |
| 6 | POV: you scan it before you buy it | Scan | anyone |
| 7 | asked when to use my retinol and it KNEW my routine | Ask — when | mascot, or you after asking |
| 8 | stop scrolling if you break out and don't know why | Triggers | anyone |
| 9 | I've been layering my skincare wrong this whole time?? | Conflicts | mascot, or you if true |
| 10 | tagged my toner and asked how often… 😳 | Ask — tag | anyone after doing it |
| 11 | my shelf had 2 conflicts. TWO. | Conflicts | anyone after the check |
| 12 | this is your sign to check what's actually in your moisturizer | Scan | anyone |

Avoid: invented numbers ("cleared in 11 days"), "dermatologist approved", "cures", before/after
skin photos. Skintel finds patterns; it doesn't treat skin.

## What's made (in `marketing/video/out/`)

- `hook-01-…mp4` … one finished video per hook below: mascot reaction (2 s) → hand-held app demo →
  Comment SKINSTEL. Silent on purpose: add a trending sound in Instagram or TikTok when posting.
- `hook-kit/text-NN.png` — each hook line as a transparent overlay in TikTok's own font (TikTok Sans,
  OFL). Lay it over **your** 2-second reaction clip in CapCut.
- `hook-kit/body-*.mp4` — the four demo bodies without a hook, to put after your reaction clip.

## How to film your own reaction (2 seconds)

1. Phone at eye level, window light, bathroom or bedroom.
2. Start mid-reaction: hand to mouth, eyes wide, look from the phone to the lens. No talking needed.
3. Film 5 takes, use the best 1.5–2 s. In CapCut: your clip → `text-NN.png` on top → `body-*.mp4` →
   add a trending sound.
4. Post 3–5 hooks with the same body over a week; keep the one that holds people past 3 s.

## Engagement check (MiroFish-style, reasoned, not simulated)

MiroFish needs its own server and API keys, so this is the skill's fallback: each segment reasoned
through in character. Directional only; your real 3-second hold rate decides.

| Segment | Stops for | Scrolls past | Best hooks |
|---|---|---|---|
| Breakout-frustrated, 18–28, cold | a reason her skin keeps breaking out | anything that smells like an ad in second one | 1, 5, 8 |
| Skincare enthusiast (uses SkinSort/Yuka) | something her current app doesn't do: conflicts between products | "scan an ingredient list" (she has that) | 2, 9, 11 |
| Sensitive / changing skin, 30–45 | a calm "which products clash" answer | hype, shouting, "POV" memes | 2, 7, 12 |
| Skeptic ("another app") | proof on screen in the first 3 s | claims with no demo | 6, 3 |

**Top three edits applied:** the demo starts the moment the hook ends (no logo, no intro); the first
demo frame already shows the result being produced; the CTA is one action (comment SKINSTEL) shown on
screen. **Biggest risk:** the mascot face reacts less strongly than a human face. Test the mascot
versions against one filmed by you; if yours wins, film more.
