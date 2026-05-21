---
name: No AI Slop In Video Edits
description: For video edits, user wants real footage / real news / real music — not synthetic placeholders
type: feedback
originSessionId: e473af87-2759-40bd-a7fc-a08863b4dda2
---
For short-form video work, do not ship AI-slop placeholders. Use real assets.

**Rule:**
- News content → fetch real headlines via WebSearch, never invent or use "plausible-looking" fakes
- B-roll → real footage (Pexels Videos, yt-dlp on CC YouTube). Not Ken Burns on stills, not abstract gradients, not generated.
- Music → real instrumental tracks (Pixabay, YT Audio Library). Not silence with "overlay later" notes unless explicitly approved.
- VO → gTTS is acceptable but must be tuned (pitch shift, tempo, EQ) so it sounds less robotic. Flag for manual VO if still slop-tier.

**Why:** User said verbatim "make it good no ai slop and etc use actual clips" on 2026-05-16 during the 30-clip AI news render. Synthetic / abstract / "good enough placeholder" output is treated as failure.

**How to apply:** Default for ALL short-form / TikTok / Reels work going forward. If a real-asset source is unavailable, ask before falling back to synthetic. Render-blocker: real assets unobtainable → ask, don't fabricate.
