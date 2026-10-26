# Skintel video engine

Renders 1080×1920 TikTok/Reels videos from HTML with headless Chromium + ffmpeg. Deterministic: every page
exposes `window.render(t)` and `window.DUR`; the recorders step `t` at 30 fps and pipe screenshots to ffmpeg.

## Pages
- `ugc2.html?v=<name>` — hook shot → hand-held phone (POV) running live Skintel screens → end card.
  Variations live in `ugc/pov.js` (`V = { scan, askwhy, mention, night, save, tag, morning, mascot }`).
  Phone scenes (`SCENES`): `green` (green-screen phone, keyed), `counter`, `bed`, `bednight` — screens are
  perspective-mapped onto the real phone with a homography (`homog()`), Dynamic Island drawn on top.
- `ad.html?ad=<same|story>` — premium ads: depth-parallax people (`cut/` = rembg cut-outs), kinetic type,
  floating iPhone, POV scenes, whip/zoom/flash transitions, grade + grain. Voiceover timing comes from `ugc/vo.js`.
- `ugc/app.js` — the Skintel screens as pure `state → HTML` functions (`SCREENS.ask / today / scan / scanreal /
  verdict / form / shelf / triggers / lock`). Mirror the shipped SwiftUI exactly when adding screens.

## Render
```bash
export NODE_PATH=$(npm root -g)          # Playwright + Chromium are preinstalled in cloud sessions
cd marketing/video-engine
node tools/still.cjs "$PWD" scan 4.4                 # quick stills -> st/
node tools/vrec4.cjs "$PWD" scan out/f1-scan          # video + out/f1-scan.events.json (taps, keys, cuts)
node tools/adrec.cjs "$PWD" same out/ad-A             # ad video + events
python3 tools/audio.py out/f1-scan.events.json out/f1-scan.wav   # needs numpy (+ soundfile for voiceover)
ffmpeg -i out/f1-scan.silent.mp4 -i out/f1-scan.wav -c:v copy -c:a aac -shortest out/f1-scan.mp4
```
Recorders hard-code Chromium at `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`; adjust if it moves.

## Sound (`tools/audio.py`)
No music by default (founder's call). Layers: soft room-tone ambience (`amb`), voiceover (`vo` list, ducks the
ambience), and synthesized effects — `whoosh swish pop click key hit riser chime` plus meme-style
`boom scratch dun boing error ding`. All synthesized here, so they're safe for paid ads. Set `"music": true` in
the events JSON to bring back the soft beat bed.

## Voiceover (`tools/tts.py`, Kokoro, runs locally)
```bash
pip install kokoro-onnx soundfile
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/kokoro-v1.0.onnx
curl -LO https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0/voices-v1.0.bin
python3 tools/tts.py lines.json vo/        # [{id,text,voice:"af_heart",speed}] -> vo/<id>.wav + durations JSON
```
Then write `ugc/vo.js` (`window.VO = {id: seconds}`). ElevenLabs is now connected too — ask before spending credits.

## Cut-outs (`tools/cutout.py`)
`pip install "rembg[cpu]"` then `python3 tools/cutout.py isnet-general-use in.png out.png …` for parallax layers.

## Assets
`photos/` (AI-generated with Higgsfield — label "AI-generated" when posting), `react/shock` and `mascot/wave`
(Kling motion frames), `ugc/` phone + screen plates. Real brand names only appear inside real app screens;
products shown as "breaking out" are fictional (Rose Cloud, Petal Glow).
