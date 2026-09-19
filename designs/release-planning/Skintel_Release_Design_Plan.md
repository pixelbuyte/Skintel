# Skintel release design plan

## Priorities and ownership

We should first make the core experience dependable: show the correct product photos, reduce unnecessary scan waiting, explain the paid plan clearly, and make movement through the app feel calmer. The plan below covers all 14 requested changes and separates work for this draft from investments to consider after cash flow.

All changes belong on the app-design-swift draft branch. The app is under review. Keep this work unmerged and unreleased until the owner chooses the next submission. Codex owns items 1 through 6 and 10 through 14. Claude owns items 7 through 9.

| Item | Requested change | Priority | Owner |
| --- | --- | --- | --- |
| 1 | Product photo after scanning | Do now | Codex |
| 2 | Entry imagery and bolder typography | Do now | Codex |
| 3 | Clear paywall wording and pricing type | Do now | Codex |
| 4 | Smooth login and navigation | Do now | Codex |
| 5 | Branded error illustration | Do now | Codex |
| 6 | Liquid Glass | Small trial later | Codex |
| 7 | More useful Journal | Do now in Claude scope | Claude |
| 8 | Mascot pull to refresh | Do now in Claude scope | Claude |
| 9 | Useful Compare suggestions | Do now in Claude scope | Claude |
| 10 | Faster and cheaper scanning | Safeguards now and benchmark next | Codex |
| 11 | Gentler haptics | Do now | Codex |
| 12 | Clearer Home page | Do now | Codex |
| 13 | Compact visual routine templates | Static preview now | Codex |
| 14 | Warm scanner palette | Do now | Codex |

Do now means a bounded change that improves the existing flow. It does not mean that the change has passed device testing. The implementation work and checks below must be reviewed together before a future release.

[[PAGEBREAK]]

## Product presentation and pricing

### 1 Show the scanned product photo

Use a verified image for the exact product and retain the captured thumbnail when a catalogue image is unavailable. Carry the image and its source through the scan result, saved history, and product detail. Show a deliberate image placeholder while loading. Never substitute an unrelated product just to fill the space.

Acceptance: a known catalogue product shows its matching photo; a product without a catalogue image shows its captured thumbnail; reopening a saved scan preserves the image. A failed URL has a readable fallback and does not leave an unexplained initial as the main result artwork.

### 2 Restore entry imagery and stronger type

Use the existing artwork on the entry screen and real product imagery where the screen presents products. Increase the weight and hierarchy of the editorial headings while preserving readable body text. Use the supplied visual references and existing licensed fonts as the design authority.

Acceptance: entry artwork appears on a cold launch; headings and buttons are visually distinct; large text sizes do not clip the title or primary action. Photos remain clear while their remote images load.

### 3 Explain the paid plan in everyday language

Make the benefit and billing terms easy to scan. Suggested benefit labels are "Unlimited product scans", "Understand your ingredients", "Spot possible sensitivity patterns", and "Build your daily routine". Show a benefit only if the purchased plan actually includes it. Avoid claiming the app diagnoses allergies or proves which ingredient caused a reaction.

Treat pricing as live store data. Give the selected price and billing period a clear hierarchy, keep renewal and trial terms readable, and retain purchase recovery and restore actions. Product marketing can use plain language while privacy information accurately describes how analysis works.

Acceptance: the selected plan, amount, billing period, and any trial terms agree with store data. Purchase cancellation, restore, unavailable pricing, and retry states remain understandable. An error is explained with an action; its presence alone should not be mistaken for an intentional part of the plan design.

### 14 Use the warm scanner palette

Apply the approved warm cream and peach direction consistently to scanner framing, progress, controls, and result transitions. Keep camera content unobscured and important text readable. Match the original reference during visual review before calling the color work final.

Acceptance: camera, permission, scanning, success, and error states use the same palette. Text and controls remain legible over both bright and dark camera scenes.

[[PAGEBREAK]]

## Home movement and routine setup

### 12 Give Home a clear first action

Make scanning the obvious primary action. Use actual recent products and concise routine context to make the page useful after the first scan. Keep the new account state simple, with a clear next step rather than empty sections or invented activity.

Acceptance: first time and returning users both see an actionable Home page. Zero, one, and several saved products lay out cleanly. Loading, offline, and empty states do not masquerade as a populated account.

### 4 Smooth login and navigation

Introduce a short, consistent transition when authentication finishes and when the selected tab changes. Keep motion tied to the actual state change so the app does not flash Home, duplicate screens, or delay input while an animation finishes.

Acceptance: login, signup, restored sessions, logout, cancelled login, and rapid tab switches behave correctly. Reduce Motion removes unnecessary movement. Device review confirms that transitions feel responsive and do not interrupt scrolling.

### 11 Make haptics gentler

Use light selection feedback for deliberate changes, reduce repeated events, and reserve stronger feedback for a meaningful outcome. Centralize the rule so other screens can adopt it consistently. Coordinate with Claude before applying it to Journal or refresh interactions.

Acceptance: a single tap produces at most one intended response; ordinary navigation feels subtle on a physical iPhone; rapid taps and refresh do not produce a burst. Simulator checks cannot establish the physical feel.

### 5 Make errors feel part of Skintel

Reuse the existing mascot artwork for recoverable errors. Pair it with a short explanation and a concrete recovery action such as retrying or returning to the camera. Keep essential permission, billing, and failure information explicit.

Acceptance: offline, failed scan, and permission states have a readable message and useful next action. VoiceOver announces the message without depending on the illustration. Custom error animation can wait.

### 13 Make templates quick to understand

Show compact routine choices with a small visual preview, a clear name, and a short description. Let users inspect the steps before starting. Use a lightweight static preview now; consider a small animation only after the simpler version is tested.

Acceptance: the main choices fit without dense promotional copy. Selecting a template reveals its steps and starts the intended routine. Large text and VoiceOver preserve the choice and action.

### 6 Evaluate Liquid Glass after the core fixes

Treat glass as a limited visual experiment on supported systems. Confirm contrast, performance, and an accessible fallback before expanding it. Motion and haptic problems have their own fixes; broad glass adoption should not delay them.

[[PAGEBREAK]]

## Claude work and shared integration checks

Claude owns the next three items. Keep Codex edits out of those feature implementations and agree on shared styling, imagery, and haptic interfaces before bringing the branches together.

### 7 Make Journal useful every day

Give users a simple way to record what they used and how their skin felt. Surface recent entries and a useful empty state. Any pattern summary should describe observations and uncertainty without presenting a diagnosis or claiming to identify an allergy.

Acceptance: users can create, edit, and review an entry; dates and linked products are clear; an empty Journal explains the next step. Large text and keyboard use remain comfortable. Saved entries survive relaunch and expected account changes.

### 8 Make mascot refresh feel calm

Use the mascot as a lightweight refresh indicator, with clear progress and completion. Keep one refresh in flight, avoid repeated haptics, and make the return to resting content smooth. Respect Reduce Motion and avoid extending the wait simply to finish an animation.

Acceptance: repeated pulling does not duplicate requests or stack feedback. Success, failure, cancellation, and slow network states settle cleanly. A physical device review confirms that the feedback feels comfortable.

### 9 Make Compare useful before advanced analysis

Suggest a small number of relevant pairs from scan history. Prefer comparable product types and exclude duplicate or unsupported pairs. Explain suggestions with simple rules such as shared category or different recorded ingredients. These rules can run on saved data without a new model call for each suggestion.

Personalize by showing ingredients the user has chosen to avoid and their own recorded concerns. Explain why an ingredient is highlighted. Missing ingredient data should remain visible as missing; a score should not imply clinical certainty.

Acceptance: zero or one scan produces a helpful prompt; several scans produce a few explainable suggestions; the chosen pair opens correctly. Rules give repeatable results and do not claim that a product is safe for an allergy. Verify that suggestions add no analysis request by inspecting request logs.

### Coordinate before integration

Share the product image model and fallback behavior, typography tokens, motion preferences, and haptic helper. Check navigation from Home into Journal and Compare, returning to the previous tab, account isolation, and deleted history. Resolve shared file changes in a draft review and run the combined app checks before any later merge decision.

[[PAGEBREAK]]

## Scan speed and model cost

### 10 Remove avoidable waiting and measure the full scan

The identified scan path can spend time on sequential catalogue timeouts and web searches before Opus analysis. Sonnet is the current fallback. Work on concurrency and request time budgets is underway. These observations do not establish a production speed improvement or prove that changing the model will fix the whole delay.

Do now: record duration for capture and upload, catalogue lookup, web search, analysis, retries, and persistence. Overlap independent lookups, bound slow external work, reuse validated results where appropriate, and cancel obsolete work. Keep product identity and ingredient evidence requirements intact. Show truthful progress and offer recovery when the overall request cannot finish.

Acceptance: timeout, cancellation, duplicate submission, and upstream failure paths finish predictably. A timeout cannot silently turn missing evidence into a complete analysis. Cached results are tied to the correct product and relevant analysis version. Timing logs contain request identifiers and stage durations without raw user photos or personal health notes.

### Measure candidates in four stages

1. Establish a baseline using a fixed set of about 100 representative cases, including known products, missing products, weak images, incomplete ingredient lists, repeated products, and declared sensitivities. Use synthetic or consented examples. Repeat runs to expose variability and report failures as well as successes.

2. Compare the current Opus route, direct Sonnet using the existing fallback, and one smaller candidate that supports the required input and structured output. Verify the provider model identifiers, availability, and current prices when the benchmark is run. Evaluate text only and image inputs separately. Do not assume that the requested assignee name "Opus 5" is an available production API model.

3. Score product identity, ingredient transcription, completeness, evidence traceability, unsupported claims, and useful handling of uncertainty. Have a person review the difficult cases without seeing the model name. Run the same prompts and fixtures for each candidate, and record any candidate specific changes separately.

4. Trial a passing candidate with limited traffic only after the owner authorizes deployment. Keep the current route available for rollback. Expand only after measured latency, quality, failure rate, and total cost meet the agreed thresholds.

### Report the result before choosing a model

Report median and 95th percentile time to a usable result, timeout rate, retry rate, escalation rate, and cost per completed scan. Include catalogue, search, storage, and fallback costs; the cheapest token price may not produce the cheapest successful scan.

Proposed evaluation targets are at least 30 percent lower 95th percentile latency and 25 percent lower cost per completed scan, with no material quality regression and no critical product identity or unsupported safety claim in the evaluation set. These are decision targets, not achieved results or a guarantee of safety. Check provider charges and realistic volume before estimating monthly savings.

[[PAGEBREAK]]

## Bounded handoffs for Opus 5

Use Opus 5 as the requested assignee label. The tasks below are ready to hand over in separate drafts. Each task returns reviewable evidence and leaves merging and release decisions with the owner.

### Handoff A Build the scan benchmark

Related item: 10. Prepare the representative fixture set and a repeatable benchmark runner. Capture stage timings, quality scores, retries, and cost for the current Opus route, direct Sonnet, and one verified smaller candidate. Agree on a spend cap before paid runs. Return the fixture list, raw measurements, a short comparison, and a recommendation that identifies remaining uncertainty. Do not change production model routing.

### Handoff B Check product photo continuity

Related items: 1 and 2. Inspect the image path from scan capture through result, history, and reopening. Exercise valid catalogue images, missing or broken URLs, captured thumbnails, and older saved records. Return a reproducible checklist with screenshots and any narrow proposed fix as a separate draft. Coordinate file ownership with Codex before editing shared models.

### Handoff C Review accessibility and device behavior

Related items: 3 through 6 and 11 through 14. On a Mac and physical iPhone, review login transitions, Home, scanner, pricing, templates, and error recovery with large text, VoiceOver, Reduce Motion, and Reduce Transparency. Record device and operating system versions. Return concise defects with reproduction steps and short recordings where useful. Reserve Journal, refresh, and Compare implementation changes for Claude.

### Handoff D Prepare a lightweight template motion study

Related item: 13. After the static choices are accepted, prototype one short optional animation using existing artwork. Compare it against the static version for clarity, load time, asset size, and reduced motion behavior. Return the prototype and measurements. Do not start a Blender asset pipeline or purchase artwork as part of this task.

## Investments after cash flow

Consider a full mascot animation set, polished three dimensional routine demos, broader Liquid Glass, and richer Journal and Compare insights after the basic release experience is proven. Prioritize an investment only when user feedback or measured behavior identifies a problem it is likely to solve, and its ongoing cost is affordable. Keep clinical validation or health claims as a separate, evidence based workstream.

## Checks before a future release

The next release review needs a successful Xcode build and device checks, correct product photos, truthful subscription terms, purchase and restore verification, accessible navigation, and clean error recovery. Scan performance claims need benchmark evidence. Shared Claude work needs a combined navigation and data check. Keep the current App Store submission and production services unchanged until the owner chooses to release this draft.
