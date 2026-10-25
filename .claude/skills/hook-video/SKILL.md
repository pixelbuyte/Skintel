---
name: hook-video
description: Make Skintel marketing videos (Reels/TikTok, 1080×1920) with the repo's own pipeline in marketing/video — reaction-hook ads (a face reacting + one text line, cut into an app demo, the Cal AI / Fastlane format), one-feature demo videos with the app UI animating live, keyword-funnel reels and transparent overlays. Use this whenever the founder asks for "vids", reels, TikToks, hooks, UGC-style ads, POV videos, a video of a feature (Ask Skintel, scan, routine, triggers, conflicts), or sends a reference reel/screen recording and says "make one like this", even if they don't say "video pipeline".
---

# Skintel hook & feature videos

Everything renders from HTML in `marketing/video/`: each composition is a page whose state is a pure
function of time (`engine.js`), screenshotted frame by frame with Playwright and encoded with ffmpeg.
That means a new video is a new HTML file or a new entry in a list, never an editing session.

Read `marketing/HOOKS.md` (hook research, hook bank, honesty rules) and `marketing/REELS.md`
(formats, captions, posting order) before writing new copy; they hold what was already decided.

## Setup (once per session)

```bash
cd marketing/video && npm ci
export CHROME_PATH=/opt/pw-browsers/chromium-1194/chrome-linux/chrome   # cloud container; omit locally
python3 ../app-store/render.py      # exports app screens + real tab-bar crops into assets/
```

## What to reach for

| Ask | Use |
|---|---|
| "make one like this reel", hooks, UGC ad | `hook.html` + `build-hooks.mjs` (reaction hook → demo body) |
| a video of one feature | `f-*.html` (live app UI: `app-ui.css`, `feature.js`) |
| keyword funnel / format reels | `reel-*.html`, `REELS.md` |
| real-looking UGC (real hand holding the phone, real B-roll) | `stock/build_stock.py` (see `stock/README.md`) |
| stickers for the founder's own footage | `overlays.html` → `shoot-overlays.mjs`; paper plane: `plane.html` → `render-alpha.mjs` |

### Reaction-hook videos

1. Add the line to `HOOKS` in `hook.html` (`[text, mascotPose]`) and the same number to `PAIRS` in
   `build-hooks.mjs` with the body that pays it off (`scan`, `triggers`, `conflicts`, `ask-when`,
   `ask-tag`, `ask-routine`). Keep the text ≤ 9 words: viewers decide in ~1.5 s, often with sound off.
2. `node build-hooks.mjs 13` renders hook 13 (2.2 s), reuses or renders the body
   (`f-<body>.html?mode=body`), joins them, and writes the kit PNG. Output: `out/hook-13-<body>.mp4`.
3. Look at frames before sending (below). Videos are silent on purpose: the founder adds a trending
   sound in-app, which also keeps music licensing on the platform's side.

### Real-footage videos (stock)

`stock/build_stock.py` makes the most convincing version: hook text over faceless stock B-roll, then
the live app tracked onto a real hand-held phone (OpenCV, `stock/composite.py`), then the end card.
Clips live in `stock/clips.json` with source page and licence. Only faceless clips (Pexels/Mixkit
forbid implying a pictured person endorses the product) and blur readable brand labels. Pexels
search pages block scripts, so find clip ids with web search (`site:pexels.com`) and download via
`pexels.com/download/video/<id>/`; Mixkit topic pages list ids directly.

### Feature videos

Copy the closest `f-*.html`. The screen is a `.mock` (390×844 pt, scaled ×1.659 into the phone);
build it from the real SwiftUI view — grep the view for its strings, fonts (`SKFont`), colours
(`SKColor`) and spacing (`SKSpace`) and copy them. Drive it with `F.type`, `F.appear`, `F.dots`,
`F.taps` (pt coordinates on the screen), `F.captions` and `F.cta`. Every feature file also works as a
hook body via `?mode=body`, and as a bare screen for compositing via `?mode=screen`
(render with `VW=886 VH=1918`).

## Rules that keep this honest (and why)

- **No fake people.** Reference formats (Fastlane, AI UGC tools) use AI actors posing as customers.
  That's a fabricated testimonial — the FTC's fake-review rule and Meta/TikTok ad policies cover it,
  and it's off-brand for "calm, honest". The face is the teardrop mascot, or the founder / a real user
  filming themselves. First-person lines ("I", "my") only go to someone they're true for.
- **Only real features, real wording.** Before showing a flow, grep the app for it. Example: Ask
  Skintel *suggests* a routine; it doesn't build one, so the video shows the person adding steps.
  Copy UI strings exactly (the check-in label is "Clear", not "Clear skin").
- **No medical claims, no invented numbers.** Patterns, conflicts, "a pattern to test, not proof".
- **No real brands** on products in demos (generic names like "Barrier Repair Cream").
- **Skintel+ features aren't "free".** Ask, scanning, conflicts and Triggers are paid; CTAs say
  "I'll DM you the link".
- **The funnel CTA is the keyword.** End on Comment SKINSTEL (→ DM → skinstel.com).

## Check before you send

Render cheap probes first: `QUERY=mode=body node probe.mjs f-scan 1 3 8` (or `QUERY=h=2 node
probe.mjs hook 0.3`), tile the PNGs with PIL, and look. Mistakes that already happened here and
were caught this way: product images overflowing their tiles (use absolutely-positioned `<img>` in
`.mark`), `seg(t, Infinity, …)` returning NaN so hidden elements showed, captions overlapping a
zoomed phone, two status bars, scrolled content under the clock. After rendering, `ffprobe` each MP4
(1080×1920, expected duration) and pull one frame with ffmpeg to confirm the fix made it in.

Renders: `FMT=jpeg` frames are ~6× faster than PNG. Run long batches with `run_in_background` and a
2-hour timeout; a 30-minute default kills a batch of six. MP4s are gitignored — send them with
`SendUserFile` and commit only the sources.
