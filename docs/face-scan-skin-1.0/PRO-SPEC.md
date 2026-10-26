# Face Scan Pro — pure-AI spec (founder spec, checked)

The founder's locked architecture for the Pro feature: a 3D sweep, 7–19 questions and a 7-day check, all AI with no
human queue. Every model id and policy below was checked on 2026-10-26. Where wording changed for App Review or
honesty, §6 lists the change and the reason. Read with `BRIEF.md` and `ADDENDUM.md`; on any conflict this file wins.

Design canvas (approve before Swift): https://claude.ai/artifact/WyFRnNyg5cLH8sgzVmnHnj. It has five screens:
the + sheet with NEW, the locked paywall, the 3-angle sweep, the questions with the checkpoint, and the 3D map with
the 7-day check (drag the day).

## 1. Three-tier model stack (no human review)

| Tier | Where | Model (exact OpenRouter id) | Price in / out per 1M tokens | Role |
|---|---|---|---|---|
| 1 Sweep + zone slicer | On device | ARKit `ARFaceAnchor` (TrueDepth) or MediaPipe canonical mesh (468 vertices, Apache-2.0) | $0 | Guide the head turn: centre 0°, left 45°, right 45°. Check light, distance and one face. Cut 5 zone crops: forehead, nose/T-zone, left cheek, right cheek, chin. |
| 2a Baseline + final read (Day 1, Day 7) | Server | `google/gemini-4-argon`, request `reasoning: { effort: "high" }` (reasoning is mandatory on this model) | $2 / $10 | 5 crops + 3 views → per-zone findings with approximate regions (§3) |
| 2b Daily read (Days 2–6) | Server | `google/gemini-3.5-flash` | $1.50 / $9 | 1 front photo → per-zone 0–100 scores, under ~2 s |
| 3 Synthesis (Day 7) + routine | Server | `anthropic/claude-sonnet-5.5`; `anthropic/claude-opus-5.5` only on retry or escalation | $2 / $10 (Opus $4 / $20) | 7-day JSON trend, Day 1 vs Day 7 findings and answers → report + conflict-checked AM/PM routine |

Fallbacks: 2a → `google/gemini-3.5-flash`; 2b → `google/gemini-3.1-flash-lite` (already in `SCAN_MODELS`). The
Anthropic direct fallback in `api/_ai.ts` (`ANTHROPIC_FALLBACK_MODEL`) does **not** inherit OpenRouter's
zero-retention routing. Never send face images to it; text-only synthesis may use it only after checking the
Anthropic account's retention terms.

**Cost estimate (needs measuring).** Token counts per image vary by provider, so these are estimates, not invoices:
- Day 1 or Day 7 read: about $0.05–0.10 with high reasoning.
- A daily read: about $0.01–0.02.
- Day 7 synthesis: about $0.04.
- **About $0.25–0.35 per user per 7-day cycle**, several times the spec's original guess. Log model and tokens per
  call (no image data) so the founder sees the real number (BRIEF §10.4).

## 2. Zero retention: what makes the promise true

- Every face request goes through OpenRouter with `provider: { zdr: true, data_collection: "deny" }`.
  - `zdr: true` routes only to endpoints with a zero-data-retention policy. A request can add ZDR but not remove it.
  - ZDR does not cover plugins or tools, so no `webSearch` on face calls.
  - `api/_ai.ts` sends no `provider` field today. Add an `AiRequest.zdr` option that sets it.
- The server never writes images to disk, a bucket or logs. No storage bucket exists today (`MIGRATION_MAP.md`
  "Journal photo: Not built"), and none gets added for this.
- **Day 7 needs Day 1's crops.** They are kept on the device only, in the app container with
  `FileProtectionType.complete`, excluded from backup. They are sent again together with the Day 7 crops and deleted
  when the cycle ends, the person deletes the scan, or the account is deleted.
- The face mesh never leaves the device (App Review 5.1.2(vi): facial-mapping data may not be used for marketing,
  advertising or data mining, including by third parties).
- Copy may say "Photos are read, then deleted" only once all of the above ships.

## 3. Wire contract (Core and API lanes both build to this)

Scores travel as 0–100 integers, so the founder's daily curve works. The app shows bands and trends, never the raw
number (§6). Zones: `forehead, nose, left_cheek, right_cheek, chin`.

```jsonc
// POST /api/face-scan → rewrite → /api/scan-ai?action=face
// request: { stage: "baseline" | "daily" | "final" | "report", cycleId, day, images: [{ role: "front"|"left45"|"right45"|"zone", zone?, base64, mimeType }],
//            answers?: {...}, history?: [DailyResult], profile?: {...}, shelf?: [...], triggers?: [...] }
{
  "quality": { "ok": true, "issues": [] },            // "too_dark" | "face_turned" | "filter" | "blurry" | "multiple_faces"
  "zones": [
    { "zone": "chin",
      "scores": { "redness": 34, "shine": 12, "raised_blemishes": 41, "flat_marks": 22, "texture": 18 },  // 0–100
      "regions": [ { "kind": "raised_blemish", "box": [0.42, 0.61, 0.08, 0.07] } ],                       // baseline/final only, normalised x,y,w,h in the crop, approximate
      "note": "A few raised blemishes along the jawline." }
  ],
  "summary": "Mostly calm. Shine on the T-zone, a few blemishes on the chin.",
  "disclaimer": "A cosmetic read of a photo, not a diagnosis."
}
// stage "report" adds: { "report": { "oil_pattern": "combination", "redness": "steady|variable", "barrier": "steady|less_steady",
//   "marks": "fading|steady|more", "suggested_active": { "name": "Azelaic acid", "why": "...", "nights_per_week": 3 } | null },
//   "routine": { "am": [...], "pm": [...], "conflicts": [...] } }
```

- **Pinned in review (Oct 26), both lanes build to these:**
  - **Images.**
    - `{role, zone?, from?, base64, mimeType}`. `from: "day1"` is allowed only on `role:"zone"` in the `final` stage; the
      server treats those crops as a reference only.
    - Caps per stage: daily 1, baseline 8, final 13 (3 views + 5 Day 7 crops + 5 Day 1 crops), report 0.
    - At most one image per (role, zone, from).
  - **Size.**
    - Base64 per view ≤ 540,000 chars, per zone crop ≤ 180,000, total ≤ 3,500,000. Over the total → 413 JSON.
      Vercel's own body limit is 4.5 MB and fails with a non-JSON 413, so the app checks first.
    - Encode views at 1024 px and crops at 512 px, JPEG q0.8. Step down to q0.7, then q0.6, if over the cap.
    - Report data ≤ 60,000 chars.
  - **Locks.** `answers.locks` is required on `report`: an array of `pregnant_or_trying`, `breastfeeding`,
    `skin_medicine`, with `[]` for none. Missing or unknown → 400. Locks never fail open.
  - **Routine.** `routine.am` / `routine.pm` are arrays of `{step, product?, note?}`. `conflicts` is `[string]`, and
    the "check with your doctor" line is `conflicts[0]` when a lock applies.
  - **`report.oil_pattern`** is `dry | normal | combination | oily`. The Day 3 pattern uses the same words.
  - **Region kinds:** `raised_blemish`, `clogged_pore`, `red_mark`, `brown_mark`, `uneven_texture`.
  - **Daily caps per user (UTC):** 8 calls in total; at most baseline 2, final 2, report 2, daily 4. A call that
    reached the model counts even if it timed out.
  - **Free scan:** a non-Pro account gets one readable `baseline` per lifetime, answered as a real Day 1 map: `locked: true`, every zone with its scores and note, and the model's summary (no regions, report or routine). `locked` means "this is the free scan; the 7-day check is locked". After that, and for every other stage, 402 `{error:"Pro required", freeScanUsed?}`.
  - **Errors:** 401, 402 `{error:"Pro required"}`, 400, 413, 429, 502/503. The app checks the status before
    decoding, and uses a 60 s timeout because the server budget is 55 s.
- Validate server-side, clamp every score to 0–100 and drop unknown keys. On bad JSON, retry once, then return
  `quality.ok=false`.
- `regions` from a vision LLM are approximate. Draw them as soft highlights and counts, never as precise outlines,
  and check run-to-run variance on the eval set (BRIEF §10.3).
- `suggested_active` comes from a fixed allow-list of over-the-counter cosmetic actives (niacinamide, azelaic acid,
  salicylic acid ≤2%, adapalene only where it is sold over the counter, vitamin C, AHA, retinol). Never
  prescription-only ingredients.
- The hard locks from Q5 remove ingredients before the model sees the list:
  - pregnant or trying, or breastfeeding: no retinoids, no high-strength salicylic acid;
  - prescription skin medicine: gentle routine only, plus "check with your doctor".

## 4. Flow (post-purchase Pro)

1. **Sweep, about 15 s.** Phone at eye level, about 35 cm. Centre, then left 45°, then right 45°, with a haptic
   tick per locked angle. Quality checks gate the shutter (canvas screen 3).
2. **Core questions Q1–Q7, about 90 s.** Chips plus "+ Add a detail or product name (optional)" on every screen.
   Prefill from what the app already knows:
   - skin type, concerns and age range from onboarding (`SkinProfile` in `SkintelCore/Models/Models.swift`);
   - Q6 from Triggers.
   The person confirms instead of re-answering.
   - Q1 30-min bare-skin feel · Q2 sting/burn · Q3 current actives · Q4 mark colour after a blemish (pink/red or
     brown) · Q5 hard locks (pregnant or trying, breastfeeding, prescription skin medicine) · Q6 ingredients that
     bothered you · Q7 goal + step limit.
3. **Checkpoint after Q7:** "Your core profile is done." Two choices: **See my results now**, or **Go deeper · 12
   more questions, about 90 s**.
4. **Deep dive Q8–Q19 (opt-in, capped at 19 total):**
   - Q8 tiny same-size itchy bumps (forehead/chest) · Q9 deep sore bumps vs small clogged pores · Q10 breakouts
     around the jaw that follow a monthly cycle · Q11 flushing (heat, spicy food, alcohol);
   - Q12 shine by early afternoon through SPF · Q13 hot showers · Q14 sweat, helmets, masks, pillowcase changes ·
     Q15 climate and air conditioning;
   - Q16 whey, dairy, B12 or biotin supplements · Q17 daily SPF habit · Q18 sleep and stress · Q19 open voice or
     text note.
5. **Day 1 result, about 10 s:** 3D map, starter routine, rings start (canvas screen 5).

## 5. Seven-day check: unlocks count scans, not calendar days

| Unlock | Needs | What it shows | How it's computed |
|---|---|---|---|
| Day 1 | Sweep + Q1–Q7 | 3D face map, blemish count per zone, starter routine | Tier 2a + answers + hard locks |
| Day 3 | 3 daily scans | Oil pattern: where shine sits | T-zone vs cheek shine across 3 scans, so one sweaty or humid morning doesn't decide it |
| Day 5 | 5 daily scans | Redness baseline, barrier steadiness | Variance of cheek/nose redness across 5 scans; a spike after a logged hot shower or workout counts as temporary |
| Day 7 | 7 scans incl. a final sweep | Full skin report: marks fading/steady/more, suggested active, final routine | Tier 2a on Day 7 crops + Day 1 crops (from device) → tier 3 synthesis |

- The Days 2–6 daily photo rides on the existing **Check in skin** action: one front photo added to the
  check-in. It is not a second habit. The reminder uses the existing notification setup in Settings.
- Missed a day? The ring waits ("2 of 3 scans"). Never extrapolate a missing day.
- Calibration logic (unlock rules, variance, trend → band) is pure Swift in `SkintelCore/Logic/`, beside
  `Streaks.swift`, with Linux tests. It takes an injected `now:` and uses it in every branch (`ios/Skintel/CLAUDE.md`
  rule 4).

## 6. Wording changed from the founder's draft, and why

| Draft | Ships as | Why |
|---|---|---|
| "Clinical Deep-Dive", "diagnostics", "clinical synthesis", "clinical vault" | "Deep dive", "skin report", "your notes" | App Review 1.4.1 scrutinises apps that could be used for diagnosing. FDA lists "analyze an image of a skin lesion" as regulated device software. Cosmetic framing keeps it a wellness app. |
| lesions, papules, micro-comedones, PIE/PIH, atrophic scarring | raised blemishes, clogged pores, red marks, brown marks, uneven texture | Same reason. Wire keys stay cosmetic too (§3). |
| "85% calibrated" / "99% precision" | "Core profile done" / "Go deeper" | No measured accuracy exists. 1.4.1 requires disclosed methodology behind accuracy claims. Revisit once the eval set has numbers. |
| "Barrier Stability %", "Healing Velocity Score" | "Barrier looks steady / less steady", "Marks: fading / steady / more" | A photo-based percentage is invented precision. 0–100 stays on the wire for trends; screens show words + glyph + trend. Founder can revisit after the eval. |
| "Baumann skin subtype" | Skinstel's own summary (oil pattern, sensitivity, mark colour) | "BAUMANN SKIN TYPES" is a registered mark (MetaBeauty, Inc.) and the quiz is licensed. Don't use the name or the 16-type questionnaire without a licence (check with counsel). |
| "Active ingredient prescription" | "Suggested active" from the allow-list (§3) | Not a prescriber. |
| "Fungal acne (malassezia) check", "Accutane" | Q8 as a pattern question; Q5 "prescription skin medicine" | Never tells someone they have a condition. Locks remove ingredients and say "check with your doctor". |
| "Encrypted, zero-data-retention" | Same, once §2 ships | It has to be literally true before it's copy. |

## 7. Open founder decisions (add to the PR #76 question list)

1. ~~Paid-only vs free first scan~~: answered, **one free scan first** (founder, Oct 26): one lifetime free baseline per account. **Free = a real Day 1 map; the week is Skintel+** (founder, Oct 26): the free scan shows the 3D map, zones and summary for real, and the 7-day check is what Skintel+ pays for. The free baseline is kept like a paid one (real cycle, Day 1 crops on device, answers), so after Skintel+ the week goes on at Day 2 with no new sweep. Was: shown as the locked map + paywall. Before that: The spec says post-purchase Pro only. BRIEF §10.1 suggests one free scan before
   sign-up to fix the sign-in leak. The canvas shows the locked-map paywall as a middle ground.
2. ~~Under-18s~~: answered, **allowed** (founder, Oct 26). Proposed: 13+ only for face scan (COPPA: a child's photo is personal information under 13), hide Q5 pregnancy options and Q16 for 13–17. Confirmed by the founder: **face scan is 13+** (an age check on the intro when onboarding age is unknown or under 18). Was: Onboarding offers "Under 18" (`AgeRange.under18`). Allow face scan for them? If yes, hide Q5's
   pregnancy options and Q16 supplements for them.
3. ~~Opus or Sonnet for the Day 7 report~~: answered, **Sonnet 5.5** (founder, Oct 26). No Opus escalation.

## 8. Handoff prompt (corrected copy of the founder's)

> We are building a Pro feature, "Face Scan Pro: deep dive and 7-day skin check", for Skinstel (repo
> pixelbuyte/Skintel, branch face-scan-skin-1.0). Read docs/face-scan-skin-1.0/PRO-SPEC.md, BRIEF.md, ADDENDUM.md and
> WORKFLOW.md first. Locked architecture:
> 1. Pure AI, no human review. Zero-retention OpenRouter routing (`provider.zdr: true`), photos never stored
>    server-side, Day 1 crops kept on device only.
> 2. Tier 1 on device: ARKit face anchor / MediaPipe canonical mesh. 3-angle sweep (0°, L45°, R45°), light checks,
>    5 zone crops (forehead, nose/T-zone, left cheek, right cheek, chin).
>    Tier 2: `google/gemini-4-argon` (reasoning high) on Day 1 and Day 7; `google/gemini-3.5-flash` for daily scans
>    on Days 2–6 (0–100 zone scores on the wire).
>    Tier 3: `anthropic/claude-sonnet-5.5` (Opus 5.5 on escalation) for the Day 7 report and a conflict-checked
>    AM/PM routine.
> 3. Questions after purchase, not onboarding:
>    - chips + an optional detail note on each;
>    - core Q1–Q7, prefilled from onboarding and Triggers;
>    - a checkpoint ("Your core profile is done": results now, or 12 more);
>    - an opt-in deep dive Q8–Q19.
> 4. Unlocks count scans: 1 = 3D map + starter routine, 3 = oil pattern, 5 = redness baseline + barrier steadiness,
>    7 = full report + suggested active.
> 5. Cosmetic language only. No diagnosis, no accuracy percentages, no Baumann name. See PRO-SPEC §6.
