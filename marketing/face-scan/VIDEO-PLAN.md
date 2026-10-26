# Face Scan launch videos — lane G plan

Owner: lane G (see `docs/face-scan-skin-1.0/WORKFLOW.md`). Builds on `marketing/video-engine/`.
Brand on screen is **Skinstel** (CLAUDE.md). In-app screens keep whatever the shipped UI says.

## Rules these videos follow
- Match the shipped UI exactly. Screen footage waits for lane E; until then only storyboard + scripts + audio.
- Copy limits from PRO-SPEC §6 / ADDENDUM: no diagnosis words, no skin age, no raw scores ("pore score 73"),
  levels shown as words. "Photos are read, then deleted" only after ZDR + on-device deletion ship.
- AI-generated people are labelled; no AI person presented as a real user; no before/after skin claims.
  Mockup films say "sample data"; App Store previews are real captures only.
- Sound: ElevenLabs voice "Kristen – Natural Upbeat Conversational Ad" (`dfeOmy6Uay63tNhyO99j`, `eleven_v4`),
  SFX `eleven_text_to_sound_v2` (whoosh, tap, scan beep, chime) + engine room tone. No music. Few generations.

## 1. Duo launch film (16:9 + 9:16) — from ADDENDUM §9
Closed phone, NEW tag on Today → unfold → selfie guide (centre, turn left, turn right) → "Reading your zones…" →
3D face turns, zones light up one by one → zone card that names a shelf product → end card
"Skinstel. See what your skin is doing." Built with `renocrypt/ios27-duo-kit` (clone, never commit) + engine audio.

## 2. Vertical scripts (TikTok / Reels, 15–25 s)
Each line has to earn the next. Numbers are from the user's own 7-day check, never claims about skin health.

**A — "I scanned my face for 7 days"** (story, real creator or founder on camera)
1. "I scanned my face every morning for seven days." *(open: why?)*
2. "Day one, my chin lit up." *(3D face, chin zone glows)*
3. "So it asked me what I'd changed." *(questions screen)*
4. "New moisturizer. Started day minus two." *(answer chip)*
5. "Day seven: chin's calmer. Forehead isn't." *(drag the day slider)*
6. "Now I know what to test next." → end card.

**B — "Your chin and your cheeks aren't the same problem"** (education, voiceover)
1. "Your chin and your cheeks aren't breaking out for the same reason."
2. "So why use one product for both?"
3. "Skinstel turns three selfies into a map of your face." *(sweep → 3D)*
4. "Five zones. Each one tracked for seven days." *(zones light up)*
5. "And it checks them against what's on your shelf." *(zone card with product)*
6. End card.

**C — POV 3D reveal** (no voice, SFX only, 9 s, loopable)
NEW tag tap → sweep (beep ×3) → wireframe → zones light up with a tap sound each → slow turn → end card.
Caption: "POV: you finally see where it's coming from."

**D — Meme cut** (engine meme SFX: scratch on the hook, "dun dun duuun" into the reveal, ding on the day-7 card)
Hook caption: "me pretending my chin isn't the problem" → sweep → chin lights up (boom) → day 7 card (ding).

## 3. Build order
1. Now: this plan, Skinstel rename in the engine (done), ElevenLabs VO for scripts B and the Duo film once the
   founder OKs the wording (voice-only, no screens needed).
2. After lane E merges: capture real screen recordings from the simulator build, add `faceScan*` screens to
   `ugc/app.js` only where a recording can't be used, render A–D + the Duo film.
3. Founder review → post. Old ads A/B still have "Skintel" in their voiceover; re-voice them with the same voice.
