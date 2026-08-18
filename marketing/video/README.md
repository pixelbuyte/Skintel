# Skintel marketing

Vertical videos and square ad stills, rendered from the same design tokens as the app —
`#A35848` terracotta, Instrument Serif / DM Sans, the site's grain and radial
gradients — composed over the iPhone mockups in `designs/previews/`.

| Composition | Length | Job |
|---|---|---|
| `v1.html` | 32s | **Culprit reveal.** Pushes into the home screen, then a crisp callout lifts out of the UI: *"Fragrance-heavy lotion precedes 3 of 4 breakouts."* The strongest hook — organic top-of-funnel. |
| `v2.html` | 27s | **Scan → verdict.** Demo: scanner, the 82 score card, ingredient breakdown. |
| `v3.html` | 21s | **The offer.** Price, feature list, terms, CTA. Built for paid and Stories. |
| `launch.html` | 50s | **Launch film.** The full story — problem, brand reveal, scan, culprit, what compounds, offer. |

### Live-UI cuts

Five compositions where the interface *animates* instead of being filmed off a
screenshot. Each is built around mechanics a PNG physically cannot do — things that
count, draw, re-order or change colour — so the data performs rather than being
photographed. They share the offer card, so any of them can carry a campaign alone.

| Composition | Length | The mechanic |
|---|---|---|
| `hero.html` | 38s | **Scan → score → culprit.** A scanline resolves each ingredient row, an SVG arc draws to 82 while the number counts with it, twelve journal bars rise before three flip red. |
| `shelf.html` | 41s | **Audit the whole shelf.** Viewfinder brackets close, a beam sweeps a barcode into existence, a donut splits 26 ingredients three ways, then six product tiles score themselves and **physically re-sort worst-first**. |
| `routine.html` | 42s | **The conflict.** A timeline rail draws downward and drops each step in as it passes; two night acids turn red; a bracket draws to join them. Then 28 journal days fill in one at a time and a barrier gauge answers. |
| `versus.html` | 40s | **Head to head.** Two products fly in from opposite edges, scores count in parallel, and five attributes grow as diverging bars from a shared spine. Cost-per-use counts out and a tick draws itself over the winner. |
| `progress.html` | 43s | **Twelve weeks.** A curve draws left-to-right with its area fill chasing it, milestone markers popping exactly as the line reaches their week. Three products get struck off a list; the result counts up. |

The moment that makes each one work is a *withheld* beat — the label that waits for
the arc, the red flip that waits for every bar, the marker that will not pop before
the line arrives. Data that resolves ahead of its own evidence reads as decoration.

`ads.html` holds six 1080×1080 stills for paid social — Reddit's automated campaigns
want at least two images to run across placements, and square covers feed and
conversation. They are six *different angles* (problem, mechanism, price) rather than
six variants of one, so the platform's rotation reports which argument works, not which
crop won.

Captions, hashtags and a posting sequence: [`CAPTIONS.md`](./CAPTIONS.md).
Voiceover scripts timed to the scene cuts: [`VOICEOVER.md`](./VOICEOVER.md).

## House style

Names for the moves, so they can be asked for by name:

| Name | What it is |
|---|---|
| **Lift** | Push in on a real UI element, blur and dim the mockup, then fade a crisp version of that element in on top. The screenshot says *where you are*; the crisp card says *what it reads*. It exists because an enlarged screenshot goes soft at ~1.6× — the handoff happens exactly when the blur would start to show. |
| **Word stagger** | Headline words rising in one at a time, slightly blurred. |
| **Drift** | The slow Ken Burns push on a phone mockup. |
| **Scrim montage** | Mockups cross-fading behind a soft gradient with text over the top. |
| **Number pop** | A big figure scaling up from 82% — the `500`, the `$20`. |
| **Offer card** | The closing price / terms / CTA block. |
| **Resolve** | A beam or line sweeps across, and content only becomes definite as it passes — barcode bars, ingredient rows. The sweep and the content share one progress value, so a thing can never resolve before the beam reaches it. |
| **Withheld beat** | The verdict, label or colour deliberately held back until its evidence is fully on screen. This is what separates a finding from a decoration. |
| **Re-sort** | Cards travelling to new grid positions under their own scores, lifting on the way. |
| **Counter** | Any figure counting to its real value — scores, money, percentages — driven from the same array that drives the chart, so the two can never disagree. |

A **Skintel cut** is the whole format: 9:16, silent, cream ground with grain, serif
headlines that stagger in, one idea per scene, always ending on the offer card.

## How it works

Each composition is an HTML page with a **deterministic timeline**: every element's
opacity, position, scale and blur is a pure function of `t` in seconds. There are no
CSS animations and no realtime playback — `render.mjs` drives Chromium to seek to
each exact frame time and screenshots it, then ffmpeg assembles the frames.

That means renders are reproducible frame-for-frame, and text stays genuinely sharp
rather than smeared by video capture. `engine.js` holds the shared easing curves and
the word-stagger, scene cross-fade and Ken Burns helpers.

## Setup

```bash
npm install
./prepare-assets.sh        # crops designs/previews/*.png into ./assets/
npx playwright install chromium
```

`assets/` is derived and gitignored. `ffmpeg` must be on PATH (with libx264 —
`ffmpeg -encoders | grep libx264`).

If you already have a Chromium you'd rather use, point `CHROME_PATH` at it and
Playwright will use that instead of downloading its own.

## Rendering

```bash
npm run render:launch                # → out/skintel-launch.mp4
node render.mjs v1 30                # name, fps
node render.mjs v3 30 1.146899 -long # + timeScale, output suffix
```

`timeScale` stretches (>1) or compresses (<1) the whole timeline without editing the
composition — the frame at time `t` renders the state at `t / scale`. It exists to fit
the **picture to a voiceover** rather than speeding a voiceover up to fit the picture,
which is always the worse trade. `skintel-v3-vo.mp4` was cut this way: Bella's read came
in at 24.1s against a 21s edit, so the video was stretched by 1.1469 instead.

Roughly 0.7s per frame, so a 30s video is about 10 minutes.

Preview single moments without a full render:

```bash
node probe.mjs launch 2.5 14 31 46   # → probe_launch/t14.png etc.
```

## Voiceover

```bash
./add-vo.sh out/skintel-v1.mp4 vo.m4a out/skintel-v1-vo.mp4          # mic recording
TTS=1 ./add-vo.sh out/skintel-v3.mp4 vo.wav out/skintel-v3-vo.mp4    # ElevenLabs etc.
./add-vo.sh out/skintel-v1.mp4 vo.m4a out.mp4 music.mp3              # + ducked bed
```

Mic recordings get a repair chain (high-pass, de-ess, compression) then loudness
normalisation to **-14 LUFS**, which is what TikTok, Instagram and YouTube all
normalise to — hitting it yourself stops the platforms adjusting you unpredictably.
`TTS=1` skips the repair chain: synthetic speech is already clean and evenly levelled,
and compressing it again only flattens it further.

Audio shorter than the picture is padded rather than truncating the video, so a
voiceover that finishes early can never cut the CTA off the end.

## Editing

Copy is in the HTML; timing is in the `S` scene table and the `render(t)` function at
the bottom of each file. The offer terms appear in `v3.html`, `launch.html` and the two
markdown docs — if the price, duration or seat count changes, all four need updating,
and `src/pages/Discount.tsx` is the source of truth for what they should say.
