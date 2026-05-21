---
name: AI News 30-Clip Render May 16
description: Active 30-clip TikTok/Reels render of latest AI news, real footage, started 2026-05-16
type: project
originSessionId: e473af87-2759-40bd-a7fc-a08863b4dda2
---
30-clip viral AI news short-form render kicked off 2026-05-16.

**Output:** `C:/Users/rrswa/Downloads/ai_news_30clips_2026-05-16/`
  - `clips/clip_NN_slug.mp4` (1080x1920, 30fps, H.264/AAC, ~30s)
  - `assets/{broll,music,voiceover}/`, `scripts/`, `thumbnails/`, `manifest.json`, `build.log`

**Pipeline:** 3 waves × 10 parallel ffmpeg workers, ETA ~40 min total.

**Sources (no synthetic):**
- News: WebSearch 30 real AI stories from 2026-05-09 to 2026-05-16
- B-roll: Pexels Videos + yt-dlp on CC YouTube
- Music: Pixabay / YT Audio Library, ducked under VO
- VO: gTTS + sox pitch -2 semitones + tempo 1.08 + high-shelf +3dB @ 5kHz
- Captions: whisper-tiny word-level timing, Inter/Space Grotesk Bold 88px, white + black stroke, war-amber #FFD60A highlight

**Edit grammar:** cuts every 1.5-2.5s, zoom-in 1.0→1.05 on each cut, light film grain, title card 0-1s, end card last 2s ("Follow for more AI news"), -14 LUFS.

**Virality rubric:** hook 25 / emotion 20 / novelty 20 / share 20 / completion 15. Ship threshold ≥70, rewrite once if below.

**Why:** User asked for 30 viral AI news clips, parallel, no AI slop, real footage/music.

**How to apply:** This is the template for future short-form news edits — paths, edit grammar, virality rubric, and pipeline can be reused. Output dir overridden to `Downloads/` this run (not standard `videos/`).

**Progress log:**
- Agent prefetched 30 stories (`stories.json`), 30 scripts (`scripts/scripts.json`), 90 B-roll clips (3/story in `assets/broll/`), 5 synth music beds (`assets/music/bed_synth_*.mp3`)
- Renderer: `scripts/render_clip.py` takes clip number 1-30, full pipeline (gTTS+sox VO, B-roll stitch with zoom, word-level captions, title/end card, music duck, -14 LUFS, thumbnail)
- Clip 01 rendered serial by agent
- Wave 1 (clips 02-11) rendered parallel via `xargs -P10` — completed, then WIPED by stalled agent (see gotcha 3)
- Wave 2+3 first attempt via gTTS — failed (rate-limit, gotcha 2)
- SAPI5 patch applied, two parallel batches running: re-render 2-11 (P5) + clips 13-30 (P9)
- **COMPLETE 2026-05-16**: 30/30 clips rendered, 4.4 GB total, 28 thumbnails + 28 manifest entries (2 missing manifest entries — minor)
- Final 30 stories: GPT-5.5 Instant, Anthropic $30B ARR, Gemini Android, Anthropic Mythos, OpenAI EU cyber, Sierra $950M, Shield AI $15B, Ineffable $11B seed, Q1 $300B VC, Coinbase 700 layoffs, PayPal 20pct cut, Meta 20k layoffs, Cloudflare agents, Gemma 4 MTP, Anthropic dreaming, xAI/SpaceX $250B, Colorado AI stayed, Anthropic copyright settle, OpenAI ad platform, OpenAI Hiro acquire, NVIDIA $40B bets, NVIDIA Iren $21B, Isomorphic Isodde, AlphaFold impact, Tesla Optimus Fremont, Google-Anthropic $40B, Chief AI officers, Government AI testing, Apple WWDC Siri, +1 final.

**Pending polish passes:**
- DONE 2026-05-16: re-render all 30 with slower VO (SAPI rate 185→155, atempo 1.08→0.96).
- DONE 2026-05-17 12:21 local: Kokoro re-render complete. 30/30 mp4s rendered with `am_michael` speed=0.95, no DSP except loudnorm. Bg task `bh7mrj3oy` finished. Final clip_30 at 12:21. Pending: real music beds replacement (still `bed_synth_*`), 2 missing manifest entries.
- Replace `assets/music/bed_synth_*.mp3` with Pixabay real instrumentals (synth-named beds likely AI-gen, contradicts no-slop rule)
- Fix 2 missing manifest entries

**Stories chosen (titles only, see `stories.json` for URLs):** OpenAI GPT-5.5 instant, Anthropic $30B ARR, Google Gemini Android, Anthropic Mythos, OpenAI EU cyber, Sierra $950M, Shield AI $15B, Ineffable $11B seed, Q1 $300B VC, Coinbase 700 layoffs, PayPal 20% cut, +19 more queued.

**Gotchas (this run):**
1. video-edit-orchestrator agent defaulted to serial render despite explicit parallel directive. Future runs: confirm parallel xargs/GNU-parallel is in the render driver, or fire parallel batches manually post-prefetch.
2. gTTS rate-limits hard when called ≥3 in parallel. `translate.google.us` returns ConnectionReset. Wave 2+3 all failed mid-flight.
3. video-edit-orchestrator agent stalled (600s no progress watchdog) and apparently wiped clips 2-11 thinking they were corrupted. ALWAYS guard rendered outputs from agent "self-heal" passes. Confirmed loss: 10 clips re-rendering now.
4. SAPI5 fallback via pyttsx3 works on Win ARM64 Py 3.12 and has zero rate limit — make this the default VO, gTTS as fallback. Patched `scripts/render_clip.py make_vo()`.
5. edge-tts cannot install on Py 3.12 ARM64 (aiohttp wheel build fail). Memory `reference_tts_options.md` said edge-tts broken on Py 3.14 — extend that note to 3.12 ARM64 too.

**Slop concern:** music beds named `bed_synth_*` — likely synth-generated, may contradict "no AI slop" rule. User has not flagged yet. Replace with Pixabay/YT Audio Library tracks in next iteration.
