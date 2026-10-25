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

## What's working on skincare TikTok right now (scraped, Oct 2026)

We scraped 240 TikToks with Apify (`clockworks/tiktok-scraper`): the top 40 for each of six searches
("skincare tips i wish i knew sooner", "skincare mistakes", "skincare routine order", "why am i
breaking out skincare", "skincare ingredient checker", "skincare app"). They were ranked by
**views per follower**: a small account getting millions of views means the hook did the work,
not the following. The top 45, with on-screen hook, spoken opening, save and share rates, are in
[`hook-research/tiktok-top.csv`](hook-research/tiktok-top.csv).

| Pattern | Best example in the scrape | Honest Skintel version |
|---|---|---|
| **The quoted bad advice**, one line in quotes, then the real answer | „Just clean your skin" — 10.8M views, 19 s | „Just stop using whatever breaks you out" → the Triggers demo (which one?) |
| **The secret someone told me** | "I'll never forget the girl who told me the secret to clear my blackheads" — 2.3M views on a 1.3K account, 6 s | Founder only, if true: "the thing that finally told me what was breaking me out" |
| **Strong opinion, first word** | "I will literally die on this hill." — 2.4M views on 2.5K followers, 2.0% saves | "I will die on this hill: check your routine for conflicts before you blame your skin" |
| **Wrong order ❌ / right order ✅** | "wrong skincare order ❌ / right order ✅" — 1.5M; "The Correct Order of your Night Skincare Routine" — 1.5M, 4.8% saves | Ask Skintel "when do I use my retinol?" with the person's own routine (ask-when demo) |
| **Talking skin creature** (the skin or pore speaks, cartoon) | "(talking pore creatures)" — 907K views, **1.0% shares** (top-5 share rate in the set) | The mascot as your skin: `talk-*.mp4` (below) |
| **Mistake/fear confession** | "what do I do" / "Guys, I'm really scared…" — 1.5M on 314 followers | Not for an ad. Leave it to real people. |
| **"Why didn't anyone tell me this sooner"** about an app | "why didn't anyone tell me this sooner because there is a app called…" — 0.6% shares | Hook 4 ("why did nobody tell me this app existed"): the mascot says it, or someone it's true for |
| **"Your moisturizer…" label distrust** | "Moisturizer might be breaking you out and the label will never tell you" | "your moisturizer might share an ingredient with everything that broke you out" → triggers |
| **"just me and the app that saved my skin"** | 127K views on a 58-follower account | Founder only, never as a fake customer |

What the numbers say beyond the lines themselves:

- **Short wins on reach.** The biggest breakouts relative to followers were 6–19 s. The long ones
  (60–355 s) come from big accounts. Our cuts are 15–17 s.
- **Saves come from instructions** (routine order, step-by-step: 4–6% save rate). Skits and
  reactions get **shares** instead. Post one of each: an Ask Skintel "order" video for saves, a
  talking-skin skit for shares.
- **Text on screen from frame one** in almost every top video; many have no voice at all.

### Stitch these (the legitimate way to "use" someone's viral hook)

TikTok's Stitch is built for this: their clip plays for the first few seconds with credit, then you
answer. It works on any video whose creator has Stitch turned on, and it borrows their hook honestly.
Good targets from the scrape: the "Just clean your skin" video (answer: "…but with *what*? here's how
to find out what's breaking you out"), the "I will die on this hill" toner video, and any "wrong
order ❌ / right order ✅" video (answer with Ask Skintel on your own routine). Stitches are filmed by
the founder in the TikTok app; copy the URLs from the CSV.

### Talking-skin videos (`marketing/video/stock/build_talk.py`)

The mascot, animated from the brand art with **Kling 3.0 on Higgsfield** (image-to-video with
generated voice, ~10 credits per 5 s), speaks as the viewer's skin. "POV: your skin can finally talk"
is on screen from frame one, the spoken line is captioned (transcribed with faster-whisper, so the
captions match the words), and then it cuts to the live app on a real hand-held phone:

| Video | The skin says | Pays off with |
|---|---|---|
| `talk-conflicts.mp4` | "You put retinol AND an acid on me last night?! I'm begging you… check first." | Routine conflict check |
| `talk-scan.mp4` | "Before you buy that… can we scan it first? Please." | Barcode scan → verdict |
| `talk-triggers.mp4` | "I've been trying to tell you what's breaking me out for two years." | Triggers |

The voice plays under the hook only; the rest is silent so a trending sound can go on in-app (keep
the original sound at ~30% so the skin is still heard). Clips are listed in `stock/clips.json`.

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
- `stock-NN-….mp4` — the same hooks over faceless stock B-roll, then the app on a real hand-held phone
  (`stock/build_stock.py`).
- `talk-….mp4` — the talking-skin skits (above): the mascot speaks with its own voice, then the
  real-hands demo.

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
