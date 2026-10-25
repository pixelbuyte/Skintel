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

Higgsfield's virality predictor on `talk-conflicts.mp4` (a proxy model, not a promise): overall 49/100,
viral potential 48, **hook 37**, **sustain 90**. Its auditory-activity curve halves at 4–5 s, exactly
where the mascot stops talking and the silent demo starts. So the next versions keep the voice going.

### The mascot talks the whole way (`stock/build_narrated.py`)

The hook, then the mascot (keyed out of a blue-screen Kling clip) narrates **our own app video** from
the bottom corner, then appears big on the end card saying "Comment Skinstel for the link!" under the
keyword. Each demo comes in four cuts:

| File | What |
|---|---|
| `mascot-<demo>.mp4` | talking-skin hook → narrated app video → mascot says the CTA (voice throughout, ~11–12 s) |
| `mascot-<demo>-silent.mp4` | the same, no sound, captions carry it (for a trending sound) |
| `pov-<demo>.mp4` | "POV: …" over a reaction shot of the mascot → narrated app video (voice) |
| `pov-<demo>-silent.mp4` | POV reaction → the full captioned app video, no sound |

POV lines: "POV: you check if your skincare is fighting", "POV: you scan it before you buy it",
"POV: you find out what's actually breaking you out".

## Which sounds these formats use (from the scrapes' music metadata)

| Format | What the top videos use |
|---|---|
| Text stories | **"Very Sad" by Enchan** (the sad-violin meme): 4 of the top 10 group-chat stories. "Dr Rick Trager Chase Theme" (chase meme) on a 557K one. |
| Glow-ups / before-after | Slowed or sped-up songs: "Loving machine (slowed instrumental)" 3.7M, "let's keep pretending pt. 2 (sped up)" 781K. |
| Skincare app videos | **"MONTAGEM GREEN RENITCH"** (Brazilian funk/phonk) on 10.8M and 4.8M; TV Girl "Hate Yourself" 2.3M; Dolly Parton "9 to 5" 1.8M. |
| All formats | 75–88% use **original sound**: their own voice or their own edit with sound effects. |

Named tracks are commercial music: add them **inside TikTok/Instagram** on the `-silent` cut (or on the
sound cut with original sound at ~40%), never baked into the file. Suggested pairing:
`text-*` → "Very Sad" (Enchan) or the chase theme; `glowup` → a slowed instrumental, cut on "we're so
back"; `mascot-*` / `pov-*` → MONTAGEM-style phonk. Business accounts only get TikTok's Commercial Music
Library; check the track is in it before posting from the Skintel account.

The sound cuts' effects are licensed Mixkit SFX (`stock/sfx.py`, Mixkit Sound Effects Free License) plus
synthesized message sounds.

## Women on camera: what's ready, what waits on credits

**Real women (works now, strongest):** the founder, a friend who actually uses the app, or paid
creators who use it and disclose it (#ad, TikTok's paid-partnership toggle). Their 2-second reaction
goes through `stock/build_selfie.py`. UGC creator marketplaces (TikTok Creator Marketplace and
similar) supply exactly this; the brief is the hook bank above plus "show the app on your phone".

**AI actor skits (when Higgsfield has credits, ~12 credits per 5 s clip):** an AI woman can *play*
"you" in a POV skit, the way an actor does in a commercial, as long as:
- TikTok's / Meta's AI-generated label is on;
- she acts out a feature (finding two products that fight, scanning before buying, logging a bad day)
  and never says it changed her skin ("this cleared my acne", "I've used it for months");
- no before/after: an AI face going from acne to clear "because of Skintel" shows a result the app
  doesn't produce. Skintel finds patterns; it doesn't treat skin.

Ready-to-run skit prompts (Kling 3.0, 5 s, sound on, 9:16, start image = a generated woman in a
bathroom mirror, no logos):
1. "POV: you finally check if your skincare is fighting": she holds her phone, reads, slowly lowers
   it, looks at the camera, mouths "two?!" Cut to the conflicts demo.
2. "POV: you scan it before you buy it": in a store aisle she scans a plain unlabeled bottle, waits,
   smiles in relief. Cut to the scan demo.
3. "POV: you log your skin for a week": she taps a check-in, a week of quick cuts, she squints at the
   phone like she cracked a case. Cut to Triggers.

## Glow-ups, text stories and real faces (second scrape, Oct 2026)

A small follow-up scrape (60 TikToks, $0.30): "skincare glow up high school vs college", "acne glow up
pov", "acne before and after pov", "skincare text message story". Top 33 in
[`hook-research/tiktok-formats.csv`](hook-research/tiktok-formats.csv).

- **Glow-ups are short and huge:** 5–18 s. "Skin glow up of the century?" 4M, "POV: You finally beat
  acne ✨" 1.5M, a 5-second #glowup #relatable 1.3M with a 1.9% share rate. The on-screen lines repeat:
  "it's so over" → "we're so back", "I was so shy to the camera until…", "I wish I didn't have the acne".
- **Every one of them is a real person's own photos.** That's the whole format, and why we don't fake
  it: invented before/after photos attributed to an app are a deceptive efficacy claim, and AI faces
  presented as customers are fake testimonials. Skintel also doesn't treat acne; it finds patterns.
- **Text stories run as series** ("PART 2", "texting series"), often long; they earn follows more than reach.
- **The Fastlane reference** (the woman: "3 years in the gym and NOW I find this??") is an AI actor. Our
  version is the same edit with a real face (`stock/build_selfie.py`).

### What we made from it

| File | What |
|---|---|
| `text-<story>.mp4` / `-silent` | **Your skin texts you** (`textmsg.html`): an iMessage-style chat with "my skin 🫠" (mascot avatar), then the captioned app demo. Sound cut = sound effects only (`stock/sfx.py`: receive tink, send whoosh, keyboard ticks, a whoosh into the demo, a pop on the end card), no music. The chat is drawn to iOS 17/18 proportions. Stories: conflicts ("retinol AND an acid toner. same night. AGAIN??"), scan ("scan it first"), triggers ("it's the same ingredient. every. time."). Post them as a series. |
| `text-mom` / `text-bestie` / `text-class` (+ `-silent`) | **Human text stories** (skits): mom discovering skincare ("why do bottles fight" → "it found 2 conflicts. screenshotting this for my book club"), your best friend before shopping ("scan it before you buy it this time" → "you cried in the car for 20 min"), a class group chat in finals week ("wait it shows what my bad days have in common??"). Built on the third scrape: the big text stories end on a twist, and dads learning skincare is its own genre (3.8M). |
| `glowup.mp4` / `-silent` | **POV: your skin in high school vs college** (`glowup.html`): the mascot's camera roll, flash photos with breakouts and a 12-product shelf ("it's so over"), then golden light, 4 products ("we're so back", "turns out my bad days had one ingredient in common"), then Triggers. Sound cut = shutter clicks and a chime. |
| `glowup.html?real=<dir>` | The same edit with **your own** photos (`hs-1.jpg`…`college-3.jpg`). Only genuine photos of you, and only if the change really came from what Skintel showed you. |
| `selfie-NN-<demo>.mp4` | **A real reaction:** `python3 stock/build_selfie.py MY_CLIP.mov --hook 1 --demo triggers` crops your 2-second reaction to 9:16, adds hook line N, then the real-hands demo and the end card. |

## Cinematic AI ads and POVs (fourth scrape, Oct 2026)

60 TikToks for "pov skincare", "pov you check your skincare", "skincare app pov" ($0.30); top 30 in
[`hook-research/tiktok-pov-ads.csv`](hook-research/tiktok-pov-ads.csv).

- **App reveals travel far from tiny accounts:** "Name of this app is BloomSkin" 4.8M plays at 8,247×
  the account's followers (sound: MONTAGEM GREEN RENITCH), Lumy Care 2.2M at 3,259×.
- **"Before you buy" is a proven angle:** "Know your skin type before you buy a new skincare" 1.1M.
- **Relatable questions pull comments:** "why is it always when you get a new skincare product…" 755
  comments on 179K plays (0.42%), about 20× the comment rate of the 10M video at the top (0.02%).

### What we made from it (`stock/build_roi.py`, `roi.html`)

AI B-roll from the ElevenLabs flow "Skinstel ROI ad" (Seedance 2.5 clips, Nano Banana 2 stills moved
with a slow push and hand-held sway), unbranded products and no faces, so nobody is presented as a
customer. A voiceover (Roxie), a ticking tension bed, sound effects, then a stretch of the app demo
and the end card. Each ends on a comment prompt anyone can answer before asking for SKINSTEL.

| File | Hook | Comment prompt |
|---|---|---|
| `roi-1ofthese` | 1 of these is breaking you out (a shelf, one bottle lights up red) | which one is it? guess in the comments |
| `roi-pov-scan` | POV: you check if it'll break you out *before* you buy it | what's the last thing that broke you out? |
| `roi-pov-conflicts` | POV: 2 of your products have been fighting every night | what's in your night routine? |
| `roi-pov-ask` | POV: it's 1am and you still don't know what order these go in | what order do *you* do yours in? |

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
- `mascot-….mp4`, `pov-….mp4` (+ `-silent`) — the mascot narrates the whole video; POV reaction cuts.

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
