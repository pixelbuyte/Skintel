---
name: TTS Options on This Machine
description: Working/broken TTS tools for video VO generation
type: reference
originSessionId: 9338b71e-b0ad-44b8-a609-821dddcfc2ec
---
**Working:**
- **gTTS** (Python `pip install gtts`) — Google Translate voice, free, no API key. Good for placeholder. Use `tld='co.uk'` for UK English (slightly deeper). Combine with ffmpeg pitch shift for cinematic narrator: `asetrate=44100*0.82,aresample=44100,atempo=1/0.82`
- **Windows SAPI** (PowerShell `System.Speech.Synthesis.SpeechSynthesizer`) — installed by default, fast, but robotic. Use for testing only.

**Broken:**
- **edge-tts** (Python) — wheel build fails on Python 3.14 (aiohttp dep). Would need Python 3.13 venv to use.
- **Zapier ElevenLabs** (`mcp__claude_ai_Zapier__elevenlabs_convert_text_to_speech`) — Zapier tasks quota exhausted ("insufficient tasks on account").
- **ElevenLabs direct account (user's)** — only **6 credits remaining of 10,000 monthly** (confirmed May 3 2026). Basically empty — won't cover even one trailer VO line. Renews monthly.
- **edge-tts** — confirmed broken: aiohttp wheel build fails on Python 3.12 ARM64 too (not just 3.14). Would need older Python or precompiled wheel.

**Premium options not yet tried:**
- OpenAI TTS API (`tts-1` / `tts-1-hd`)
- Coqui XTTS (local, heavy install)

**Kokoro TTS (FREE, BEST QUALITY, WORKING):**
- pip: `kokoro-onnx` + `numpy` (use `wave` module not soundfile on ARM64 Python)
- Models at `C:/Users/rrswa/tts/kokoro/` — `kokoro-v1.0.onnx` (310 MB) + `voices-v1.0.bin` (28 MB)
- Source: https://github.com/thewh1teagle/kokoro-onnx
- Voice: `am_michael` = deep American male narrator. Other good ones: `bm_george` (British), `am_adam`, `am_fenrir`
- Speed 0.92 = cinematic measured pace
- ONNX runtime, no torch needed, ARM64-compatible
- **Best free TTS found — top tier, beats Piper**

**Piper TTS (FREE, REALISTIC, WORKING):**
- Installed at `C:/Users/rrswa/tts/piper/piper.exe`
- Voice model: `en_US-ryan-high.onnx` (120 MB, deep male narrator)
- Source: https://github.com/rhasspy/piper
- Voice models: https://huggingface.co/rhasspy/piper-voices
- Usage: `echo "text" | ./piper.exe --model en_US-ryan-high.onnx --output_file out.wav`
- No Python deps. Standalone exe. Neural quality. Best free option found.
- For deeper cinematic feel post-process with: `asetrate=22050*0.92,aresample=44100,atempo=1/0.92` + `aecho=0.6:0.4:80:0.25`
