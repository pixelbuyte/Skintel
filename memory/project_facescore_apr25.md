---
name: FaceScore Website Apr 25
description: Face scoring/looksmaxxing PSL rating website built with GPT-4o Vision, local Node server
type: project
originSessionId: 81b7dd89-a78d-4937-8cf0-4d1365aea71f
---
Built face scoring website at `C:/Users/rrswa/facescore/`.

**Why:** User wanted looksmaxxing PSL rater with photo upload, tier labels, appeal system, leaderboard, share card.

**How to apply:** If user asks about this project, files are at that path. Run with `node C:/Users/rrswa/facescore/server.js` → open `http://localhost:3000`.

## Files
- `index.html` — full UI
- `style.css` — dark theme
- `app.js` — all logic (GPT-4o Vision API calls, scoring, appeal, leaderboard)
- `server.js` — local HTTP server (needed for camera access)

## Features
- Upload photo or camera capture (front cam on mobile)
- GPT-4o Vision scores face → PSL score (1-10, one decimal)
- Tier labels: Subhuman / LTN / MTN / HTN / Chadlite / Chad / Gigachad
- Percentile (Top X%)
- 8 category bars: Jaw, Eyes, Symmetry, Nose, Lips, Skin, Cheekbones, Harmony
- Appeal Score (1-10, separate sexual/physical appeal dimension)
- Appeal Dispute: re-submit new photo, takes best score (one chance)
- Brutal verdict + improvements + scientific breakdown
- Share card (canvas PNG download or native share on mobile)
- Leaderboard (localStorage, top 50)

## API
- Currently uses OpenAI GPT-4o Vision (~$0.01–0.02/photo)
- User considering switching to Google Gemini (free tier) — not yet implemented
- API key stored in localStorage under key `fs_api_key`

## Unresolved
- Switch to Gemini API for free tier (user asked, not done yet)
- No backend/database — leaderboard is localStorage only
- Not deployed publicly yet
