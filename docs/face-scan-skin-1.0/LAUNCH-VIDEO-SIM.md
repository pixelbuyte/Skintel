# Face Scan launch video: audience-reaction rehearsal

**Read this first: this is a reasoning exercise, not a simulation.** MiroFish was not running (checked `localhost:3000`
and `localhost:5001` on 2026-10-26, no response on either) and was not installed, because it needs LLM and Zep API keys
we must not create. Everything below is one model reasoning through four viewer personas in character, following the
`mirofish-video-engagement` skill's manual fallback. It gives a directional read on where people stop and what to fix.
It is not a forecast of views, installs or sales. Labels High / Med / Low are my judgement, not measured rates.

Goal: app installs, then Skintel+ subscriptions. Segments tested: S1 teens and young adults with breakouts on TikTok,
S2 skincare enthusiasts who track products, S3 people with sensitive or reactive skin, S4 sceptics wary of AI and face data.

## 0. What I found that changes the brief

Checked against this branch's code (`face-scan/video-sim`, cut from the Face Scan work). Not compiled or run; `ios-ci` status unknown.

1. **The free result in code is a locked map, not per-zone words.** After sweep and quiz, a free user gets
   `FaceLockedView`: zones that have findings are softly lit and labelled `LOCKED`, headline "N AREAS FOUND", button
   "Get Skintel+" (`FaceLockedView.swift:59`, `FaceScanFlowView.swift:314`). Per-zone words ("metric · band") are in the
   paid `FaceResultView` (`:137-142`). The brief for this task says the free scan has per-zone words. One of them is out of date. The
   revised script below is written to be true either way; verify before capture.
2. **"The 3D face is a model, not a scan of you"** is printed in the consent alert (`FaceScanFlowView.swift:96`) and on
   the sweep screen (`SweepView.swift:144`). VIDEO-PLAN script B line 3 ("turns three selfies into a map of your face") and
   any "your face in 3D" voiceover contradict the app's own disclosure. A sceptic will quote the app at us.
3. **Name drift on screens we would film:** `FaceLockedView.swift:59` "Get Skintel+", `:102` "Everything else in Skintel",
   `SweepView.swift:192` "Allow the camera for Skintel", while the consent alert says "Skinstel". A viewer hears
   "Skinstel", installs, and sees "Skintel".
4. **The hook can promise what the free scan paywalls.** "My chin lit up" opens a loop (what does it say about my chin?)
   that the free scan answers with "LOCKED". The CTA has to say what is free and what is paid.
5. **"Photos are read, then deleted"** may be voiced only once zero-retention routing and on-device deletion are live
   (PRO-SPEC §2). The consent alert already says it. I could not verify production. The revised script does not rely on it.

## 1. Seed (skill Step 2 template)

```
# Seed: Skinstel Face Scan launch video (Duo film, 25 s cut)

## Context
Platforms: TikTok and Instagram Reels (9:16), plus a 16:9 cut for the site and App Store. Launch window: late Oct 2026.
The brand account is new; marketing/500-SEATS-10K-PLAN.md itself says new accounts sit at low views while the
algorithm classifies them. Funnel facts from BRIEF §10.1 (checked by that session, not re-checked here): 3 App Store
downloads Oct 22-24, no new account since Oct 21, zero sign-in or sign-up attempts in the auth logs Oct 22-25.
BRIEF §10.7: raw screen-recording app reveals did well (4.8M views on a 582-follower account, 2.2M on 675; n=2);
every post has sound; silent posts sat at the ~100-view floor. Competitor landscape is not in the inputs and is not assumed.

## The asset
Storyboard (ADDENDUM §9), no timings and no voiceover written yet. Built with the Duo kit; mockup footage labelled
"sample data". Sound: ElevenLabs female voice, SFX, no music.
 1. Closed foldable phone, NEW tag visible on Today
 2. Phone unfolds
 3. Selfie guide: centre, turn left, turn right
 4. "Reading your zones..."
 5. 3D face turns, zones light up one by one
 6. Zone card that names a product on the user's shelf
 7. End card: "Skinstel. See what your skin is doing."
Assumed timing for a 25 s cut: 0-3, 3-6, 6-11, 11-13, 13-19, 19-22, 22-25 s.
Companion vertical scripts A-D (marketing/face-scan/VIDEO-PLAN.md): A "I scanned my face for 7 days" (creator on camera),
B "Your chin and your cheeks aren't the same problem" (voiceover), C POV 3D reveal (SFX only, 9 s), D meme cut.
Claims the video makes or implies (probe each for credibility):
 - "See what your skin is doing" (outcome promise, no specifics)
 - zones light up (it finds something on your face)
 - zone card names a shelf product (it connects the scan to your products)
 - script A: "chin's calmer, forehead isn't" after 7 days (skin change)
 - script B: "chin and cheeks aren't breaking out for the same reason" (causal claim); "a map of your face" (3D)
Caption, thumbnail, on-screen text beyond the end card: not specified.

## Offer and CTA
Free: one scan with a Day 1 3D face map and zone-by-zone result. Paid (Skintel+): 7-day check, skin report, routine.
Price and trial terms are not in the inputs. CTA as written: end card tagline only, no action, no store badge.
Next step after tapping through: App Store page, install, onboarding.

## Friction points
 - Age: 13+ only (self-declared yes/no when onboarding age is unknown or under 18)
 - Camera permission
 - Consent alert: photos, answers, skin profile, shelf and Triggers go to third-party AI providers (OpenRouter: Google,
   Anthropic) with zero data retention; photos are read then deleted; 3D face is a model, not a scan of you
 - Sign-in (Apple, Google or email) before the scan
 - Sweep of 3 angles, about 15 s
 - Questions Q1-Q7, about 90 s, before any result; result "Reading your skin" about 10 s
 - Free result then a Skintel+ wall; trust: face photos, AI, unfamiliar brand, "Skinstel" in ads vs "Skintel" in places in-app

## Audience segments
S1 Teens and young adults with breakouts (TikTok). 13-24, cold feed, thumb on the scroll. Believe their skin is "bad"
and that someone, somewhere, knows the fix. Want to know what is causing it and what to buy. Distrust anything that
looks like an ad, long forms, and paying. Many are 13-17: the age gate, no card of their own.
S2 Skincare enthusiasts who track products. Already use ingredient checkers, spreadsheets or apps. Believe in
data and routines; want specifics (ingredients, which product, what changed). Tolerate setup effort. Distrust vague
"AI" claims, invented precision and scores they cannot audit.
S3 People with sensitive or reactive skin. Burned by past products; fear a new one. Want to find what sets them off and
a safe routine. Believe patterns exist. Distrust overclaims, medical-sounding promises, and anything that could be pushing
actives at them.
S4 Sceptics wary of AI and face data. Believe face data is biometric data and "free" means they are the product. Want to
know where the photo goes, who keeps it, and why a skin app needs their face. Distrust AI-generated people, vague
privacy copy, new brands, and accounts required up front.

## Prediction questions
- Will each segment watch past the first 5 seconds? Where do they drop off?
- Which segment is most likely to tap through, and which is most likely to scroll past?
- What would make a viewer share or comment, and what would make them report it or think it's a scam?
- Does the CTA make the next step obvious? What would stop someone at the download or checkout step?
- Does anything in the film promise something a first-time free user will not see?
- Which segment becomes a Skintel+ subscriber, and what would they need to see first?
```

## 2. Drop-off map (reasoning, not measured)

Risk of leaving at each step. "Video" rows use my assumed 25 s timing; the post-video rows are the real first-run path in the code.

| Step | S1 teens | S2 trackers | S3 sensitive | S4 sceptics |
|---|---|---|---|---|
| 0-3 s closed phone, NEW tag | **High** | Med | **High** | High |
| 3-11 s unfold, selfie sweep | Med | Low | Med | Med |
| 11-19 s reading, 3D reveal | Low | Low | Med | Med |
| 19-22 s zone card with shelf product | Med | Low | Low | Med |
| 22-25 s end card, no action | **High** | **High** | **High** | **High** |
| App Store page, install | Med | Med | Med | **High** |
| Sign-in before the scan | Med | Med | Med | **High** |
| Age gate, consent, camera permission | Med | Low | Med | **High** |
| Sweep (about 15 s) | Low | Low | Low | Med |
| Questions (about 90 s) | **High** | Low | Low | Med |
| Free result (locked map) | Med | Med | **High** | **High** |
| Paywall to subscribe | **High** | Med | Med | **High** |

- **S1 teens** stop at second 1 to 3 (nothing is happening to a face, no problem is named) and at the 90 s quiz. They are the
  best fit for the reveal itself, and the most likely to comment "what is this app". Many cannot pay without a parent.
- **S2 trackers** are the most likely to watch to the end, install and finish the quiz. They convert to paid only if the free
  result proves there is depth behind the lock; the zone card with a shelf product is their strongest beat.
- **S3 sensitive skin** need "why this happens and what to avoid", not a pretty map. They stop at a locked result on
  something that feels health-adjacent, and respond well to "cosmetic read, a pattern to test".
- **S4 sceptics** will not convert from a cold ad. The aim is that they do not report it and that the replies carry the
  answer. They stop at the consent alert (jargon: OpenRouter, "zero data retention"), at sign-in, and at "LOCKED".

Answers to the seed questions: most likely to watch and engage is S1, most likely to install and finish is S2, most likely to
scroll past is S3 at the opener and S4 throughout. The CTA does not make the next step obvious. The most likely
subscriber is S2, then S3.

## 3. Top 3 drop-off points

1. **0 to 3 s.** Closed phone and a small NEW tag. No face, no motion, no problem named, no voice line. A foldable also
   reads as a device ad to people who do not own one (the feature does not need one; BRIEF §10.2 covers other phones).
2. **22 to 25 s end card.** "Skinstel. See what your skin is doing." is a tagline. It has no action, no store badge, no
   "free", and the brand is new and easy to misspell (Skintel/Skinstel). Even an interested viewer has no next step.
3. **First run, before any result:** sign-in, then 13+ question, consent alert, camera prompt, a 15 s sweep and a 90 s quiz.
   The founder's own funnel data (zero sign-in attempts in four days) says the front of this path already leaks.

## 4. Top 3 conversion blockers

1. **A stack of friction before any payoff.** Sign-in, age, consent, camera, sweep, quiz: roughly two and a half minutes of
   effort before a free result. Hits S1 and S4 hardest. The film shows none of it, so it arrives as a surprise.
2. **The free result does not prove the paid value, and the film over-promises.** In code the free map says LOCKED. The film
   shows a 3D turn and a shelf-product zone card; a new account has an empty shelf, so that card will not appear in the first
   scan. Mismatch between promise and first-run reality is what produces 1-star reviews, refunds and no subscription.
3. **Trust.** Face photos plus AI plus a new brand. The consent alert is dense and technical; the film says "your face" while the
   app says "a model, not a scan of you"; the name changes between ad and app; an AI-generated face anywhere would be read
   as proof the whole thing is fake.

Drop-off 3 and blocker 1 are the same wall seen from two sides: one is where people leave, the other is why.
Out of scope for a script, but the biggest lever: BRIEF §10.1 proposed a scan before sign-in. The founder chose one free
scan per account (PRO-SPEC §7), so sign-in stays in front. A shorter consent alert and a Q1-Q3 quick start would do more
than any edit to the film.

## 5. Trust signals

Use (all true, all checkable in the shipped screens):
- The consent alert appears before the camera is used: show it, for two seconds.
- "13+" and the age question exist. "A cosmetic read, not a diagnosis" is on every result screen.
- "The 3D face is a model, not a scan of you": say it; it defuses the biometric fear.
- Real person on camera (founder or a consenting creator), real screen recording, a real clock on the sweep. Raw beats
  polished (BRIEF §10.7). Mockups are labelled "sample data"; paid creators are labelled #ad.
- Specific, small, true numbers: three angles, about fifteen seconds, five zones.
- Say what is free and what is paid, in the video, not in the App Store listing.
- The face mesh never leaves the device (PRO-SPEC §2); Day 1 close-ups stay on the phone. Usable once confirmed shipped.

Drains trust:
- AI-generated people (S4 will find it); an AI person presented as a user is also against our own rule.
- Before/after, "calmer skin", "accuracy", "dermatologist-grade", skin age, scores, "first of its kind".
- A tagline-only end card and "free" with no mention of the paywall.
- Polished foldable mockups with no real capture; "Skinstel" in the voice and "Skintel" on screen.

Likely to comment or share: the reveal (satisfying, loopable), "which zone lit up for you", the sweep (it's visibly fun).
Likely to report or call a scam: undisclosed AI faces, a skin-improvement claim, "free" that ends in a wall, and the
"where does my face go" question left unanswered in the comments. Pin a reply that quotes the consent alert.

## 6. Recommended script edits, ranked

Ranked by impact per effort. Impact and effort are my estimates.

| # | Edit | Impact | Effort | Helps |
|---|---|---|---|---|
| 1 | Replace the tagline end card with one action shown and spoken: App Store search "Skinstel", then "First scan free. The 7-day check is paid." | High | Low | all |
| 2 | Rebuild 0-3 s: first frame is the glowing map or a hand and phone, first-person line in the first 2.5 s, no closed phone, no logo. | High | Low | S1, S3 |
| 3 | Show the front of the path in the film: Apple sign-in tap, the consent alert, the real timed sweep. Say "about fifteen seconds" and "a few quick questions". | High | Low | S1, S4 |
| 4 | Film what a brand-new account sees (empty shelf, free locked map) or label the paid view "Skintel+ view". Drop the shelf-product card from the cold cut. | High | Low | S2, S3 |
| 5 | Fix claims: say "zones", "a model", never "your face in 3D" or "a map of your face". Cut script A "chin's calmer" unless it is the creator's real result, and script B's causal line. | Med | Low | S3, S4 |
| 6 | Real person or hand only. If any AI person appears: platform AI label plus an on-screen "AI-generated" tag. | Med | Low | S4 |
| 7 | Burned-in captions for every line, and a "Real screen recording" or "Sample data" tag. | Med | Low | all |
| 8 | Name consistency: voice and captions say Skinstel; fix or avoid the screens that say "Skintel" (see §0.3) before capture. Product change, not mine. | Med | Low | S4, S2 |
| 9 | Cut three hook variants (same footage, new first line) and test 48 h, one per segment (§7). | Med | Low | all |
| 10 | A 15 s reply video, "Where does the photo go?", using the consent alert. | Med | Med | S4, S3 |
| 11 | Move the Duo film to the site and App Store (16:9); use the raw 9:16 cut for cold TikTok. Needs real capture, so after lane E. | Med | Med | S1, S3 |

Post caption (suggested): "Face scan is 13+. A cosmetic read of a photo, not a diagnosis. First scan free; the 7-day check
is paid. #ad if a paid creator."

## 7. Revised 25 s script (9:16)

One viewer: someone with breakouts who wants to know where they come from. Sound on, with burned-in captions for sound off.
ElevenLabs "Kristen" for the voice (no new generations made for this rehearsal), SFX only: scan beep, tap per zone, chime
at the end. No music. Hook under 3 s, one proof point, friction in the open, one CTA.

| Time | Visual | Voice (burned-in caption) | SFX |
|---|---|---|---|
| 0:00-0:02.4 **Hook** | Frame 1 is already the map: clay face model turning, [zone] glowing, held in a real hand. No logo, no black. | "I scanned my face. My [chin] lit up." | scan beep, soft tap |
| 0:02.4-0:08 **Proof 1** | Real screen recording of the sweep: centre, left, right, with the clock from the recording on screen. Tag "Real screen recording". | "Three quick selfies. About fifteen seconds." | tick per angle |
| 0:08-0:14 **Proof 2** | "Reading your skin", then five zones light one by one on the model; hold 1.5 s in silence on the full map. Small text: "Cosmetic read, not a diagnosis. 3D model." | "Five zones. It lights up the areas that show something." | tap per zone |
| 0:14-0:19.5 **Friction** | Tap Continue with Apple, then the consent alert held 2 s ("Read your skin with AI?"), then Allow. Text: "Asks first. 13+." | "It tells you where your photo goes before it reads it." | tap |
| 0:19.5-0:25 **CTA** | App Store search types "Skinstel", the icon, Get. Last 2 s: icon, "Skinstel", "First scan free. 7-day check is paid." | "First scan's free. The 7-day check is paid. Search Skinstel." | chime |

Rules for the take:
- [chin] is whichever zone actually lit on the real take. Never script the result.
- The proof point is true and checkable: the clock is the real clock. If the real sweep takes 22 s, say "under half a minute".
- Capture a brand-new account's free result. If the zones read LOCKED, the CTA line covers it; if they carry words, keep them.
- No AI-generated people. The person on camera is the founder or a consenting creator; paid means #ad.
- Do not say "deleted" or "zero retention" in the voice until the founder confirms ZDR and device deletion are live.
- Sign-in and consent clips are the real screens, shortened by cuts. Do not hide the Skintel+ wall; the CTA names it.

Hook variants for A/B (same footage, first line only, each under 3 s):
- S2 trackers: "I tracked my products. Then my face."
- S3 sensitive: "Reacts to everything? Map it first."
- S4 sceptics: "Where does your face photo actually go?" (cut to the consent alert as beat 2)

## 8. Confidence note

- **Method:** one model reasoning in character for four personas. No MiroFish run, no real viewers, no analytics. A
  language model tends to over-reward polish and under-weigh ad fatigue, timing, algorithm distribution and distrust of an
  unknown brand. All three could make real reactions worse than this reads.
- **Strong (structural or checkable in code):** the missing CTA and action; the free result being locked in this branch; the
  "model, not a scan of you" contradiction; the Skintel/Skinstel name drift on screens; the hook promising what the free scan
  paywalls.
- **Medium (plausible, untested):** the ranking of the three drop-offs, the quiz as the S1 cliff, the sceptic reading of the
  consent alert.
- **Weak:** every High / Med / Low cell, and the ordering between segments. The only numbers in the inputs are three
  downloads and zero sign-in attempts (BRIEF §10.1, not re-checked) and two reveal videos (n=2, survivorship). The hook benchmarks in
  `marketing/VIDEO-SCRIPTS.md` come from third-party blogs I did not verify.
- **Not checked:** prices and trial terms, whether `ios-ci` is green, whether zero retention is live, whether the free
  result is changing, what the Duo kit renders.
- **Next step that beats this document:** cut the three hooks from §7, post them, and read installs per 1,000 views plus the
  BRIEF §10.5 funnel events. Treat the real numbers as the answer.

## Appendix: inputs read

`ADDENDUM.md` §9 and §2; `BRIEF.md` §7, §10.1, §10.2, §10.5, §10.7; `PRO-SPEC.md` §2, §4, §5, §7; `WORKFLOW.md`;
`marketing/face-scan/VIDEO-PLAN.md`; `marketing/VIDEO-SCRIPTS.md` (hook research); `marketing/500-SEATS-10K-PLAN.md` (header);
`marketing/video-engine/README.md`; `ios/Skintel/Skintel/Features/FaceScan/FaceScanFlowView.swift`, `FaceLockedView.swift`,
`SweepView.swift`, `FaceQuizView.swift` (read-only). Nothing under `marketing/` was edited (lane G owns it).
