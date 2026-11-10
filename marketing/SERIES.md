# Skinstel — cinematic mini-series ("We found her")

A crime thriller that turns into a family drama, in four ~30 s vertical episodes:
**1 We found her · 2A It was for her · 2B The morning after (alternate 2) · 3 It was worth it.**
The founder's full script is the source; this file is the production plan for shooting it on
Higgsfield, and what has to be true for it to ship.

## Status

- **Blocked on Higgsfield.** It isn't connected in the session that planned this. Connect it at
  claude.ai/customize/connectors, then start a new session (connectors load at session start).
- ElevenLabs can't carry it: a 5 s 720p Seedance clip costs ~16.8k credits, so ~120 s of
  finished video (with takes) is several times the 90k-credit monthly plan.
- **Done without credits:** the logo-as-pin board look (`out/board-logo-pin.mp4`): the corkboard
  shot from the "1 of these" ad with the bottle painted out and the real app icon pinned where the
  strings meet, matched to the lamp light, then a slow push-in with lamp flicker and grain. The
  same composite goes on the Higgsfield board shot (prompt it with an empty centre).

## Changes to the script (and why)

| Script says | We do | Why |
|---|---|---|
| SKINTEL in dialogue and cards | **Skinstel** | The app's official name; the icon stays as is. |
| "ingredient or routine insight" | Scan → verdict ("86 · good match · nothing on your trigger list"), ingredient list, routine conflicts | What the app really does (`f-scan`, `f-conflicts` renders). |
| Ep 3 notification "if supported" | **"Morning routine · Your AM steps are ready on Today."** | The real reminder text (`SettingsView.swift`, `RoutineReminders.apply`). |
| App screens | Composite our real renders onto the phone in post | AI phones draw wrong text. Never let the model draw the UI. |
| Maya's skin | Same acne in every episode, a little calmer and more confident in Ep 3, never clear | No transformation claims; Skinstel finds patterns, it doesn't treat skin. |
| End card | "Understand your skin. One step at a time." / "Download Skinstel" / "Available on the App Store" | Text only, no Apple badge artwork unless we use Apple's official badge files. |

The characters are fictional actors in a scripted drama (clearly a story, nobody presented as a
real customer), so this is fine where an AI "user testimonial" is not.

## Locked references (generate first, reuse in every shot)

1. **David**, 43, detective: short dark-brown hair, light stubble, tired hazel eyes, charcoal
   trench coat over a white shirt.
2. **Maya**, 17: shoulder-length dark-brown hair, brown eyes, natural visible acne on cheeks and
   forehead, at-home clothes.
3. **The runner**, ~25: black hoodie, dark face covering, phone in hand.
4. **Detective office at night**: rain on the windows, desk lamp, a huge corkboard of red string
   with an **empty centre** (the logo pin goes there in post).
5. **Maya's bedroom**: vanity mirror, bed, warm lamp; same layout at night and at sunrise.
6. **Real assets**: `ios/Skintel/Skintel/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png`,
   screen renders `marketing/video/out/skintel-f-*-screen.mp4`, App Store slides `marketing/app-store/out/`.

## Shots (one Higgsfield clip per line, ≤ 10 s; cut and sequence in post)

**Ep 1 — We found her** (thriller, rain, ticking clock → percussion)
1. 0–5 Push in on the board, David studying it: "Where are you…?" *(logo pinned in post)*
2. 5–9 Door flies open, young detective: "Boss! I think we've got her!" — David: "Where?"
3. 9–15 Smash cut: rainy alley, the runner through puddles, two detectives chasing, handheld. "STOP!"
4. 15–20 Cornered at a wall; slow orbit; David lowers her face covering; score drops out.
5. 20–25 He takes her phone; ECU of the screen *(real icon composited)*: "After all this time…"
6. 25–30 David's face: "Finally. I found it." Hit. Black: "BUT WHY DID HE NEED IT?" / "PART 2".

**Ep 2A — It was for her** (warm, quiet)
1. Night, rain stopped; David opens Maya's door; she's at the mirror, looking at her cheek.
2. "Dad? Where have you been?" — "Looking for something."
3. He hands her the phone: "What is it?" — "Something that might help you understand your skin."
4. Phone insert *(real scan → verdict)*: "Wait… I can actually check my products?"
5. "One step at a time." — "You really did all that for me?" He nods.
6. Hug; dolly back through the doorway. Card: "Sometimes the answer is closer than you think."

**Ep 2B — The morning after** (alternate 2, almost no dialogue)
1. Night; Maya asleep; David sets the phone on the nightstand *(real icon)*: "I found it, sweetheart."
2. He closes the door; hold on the phone; cut to sunrise.
3. Maya wakes, picks up the phone, confused.
4. Inserts *(real)*: scan, ingredient list, routine conflict. "Wait… seriously?"
5. David in the doorway. "Dad… was this you?" — "Just give it a chance."
6. She smiles; push in on the icon. Card: "The real test begins."

**Ep 3 — It was worth it**
1. "THREE WEEKS LATER." Sunrise; phone by the pillow; the real Morning routine reminder.
2. Inserts *(real Today AM routine)*; Maya at the bathroom mirror, same skin, easier in it.
3. David knocks: "Morning, sweetheart." — "Someone's in a good mood." — "I finally feel like I
   understand what I'm using."
4. He glances at the phone; 1 s flashback to the chase; "Guess it was worth the trouble."
5. "You didn't have to chase someone for an app, Dad." — deadpan: "I'd do it again." Hug.
6. End card (above) on the real icon.

## Post (no credits, our pipeline)

- Phone inserts: track the phone screen (`stock/track.py`, `composite.py`) and map the real screen
  renders onto it, as the stock hand-held demos already do.
- Board: paint out whatever sits in the centre, pin the icon, light-match, grain (as in the proof).
- Cards and captions: an HTML overlay page like `roi.html`, rendered with `render-alpha.mjs`.
- Sound: Higgsfield's native dialogue and ambience; our ticking bed and hits where they help.
- Each episode exports alone at 1080×1920, about 30 s.
