---
name: VO Speed Preference for Short-Form
description: Default VO pace was too fast on first 30-clip render; user wants slower
type: feedback
originSessionId: e473af87-2759-40bd-a7fc-a08863b4dda2
---
For TikTok/Reels short-form VO, default pace should be slower than typical narration.

**Rule:**
- SAPI5 rate ≤ 160 words/min (not 185)
- ffmpeg post-process: do not stack a positive atempo on top of a fast TTS rate. If TTS is already at target wpm, atempo = 0.95-1.00 (slight slow), never above 1.05.
- Target listener perception: deliberate, authoritative, not rushed. 30s clip ~70-80 words spoken, not 100+.

**Why:** User flagged on 2026-05-16 after first 30-clip ship: "the voiceover is too fast fix that". Cause was SAPI rate=185 stacked with atempo=1.08 — compounded speedup.

**How to apply:** For any short-form VO render going forward, set conservative SAPI rate (155 default) and neutral-to-slow atempo (0.96 default). Test on 1 clip before batch render.

**UPDATE 2026-05-17:** User flagged second render as "sounds weird" — SAPI + pitch-shift + atempo chain stacked artifacts that made the voice unnatural. Switched to Kokoro neural TTS (`am_michael`, speed=0.95, NO ffmpeg pitch/tempo, loudnorm only). Lesson: don't stack DSP on a robotic synth voice — use a quality neural TTS raw. Default for all future short-form VO = Kokoro at C:/Users/rrswa/tts/kokoro/.
