# Skintel — Founding Batch Launch Plan

**Window:** Wed 12 Aug → Sun 16 Aug 2026 (4.5 days)
**Offer:** 3 months of Pro for $20, one-time, no auto-renew. 500 seats.
**Stretch target:** 500 × $20 = $10,000
**Realistic target:** ~115 seats / ~$2,300
**Budget:** $500

> **Revision note.** The first draft of this plan was built backwards from $10,000 and assumed ~60 posts in four days. That volume is not achievable solo, and the tiers below have been revised down accordingly. The strategy is unchanged; the scale is honest now.

---

## 1. The honest math

### $10,000 from $500 is 20× ROAS — a $1.00 CPA

Benchmarks for this exact vertical:

| Metric | Benchmark |
|---|---|
| DTC beauty median CPA, TikTok | **$12.80** (IQR $7.40–$21.10) |
| Beauty CPC, TikTok | $0.60–$0.90 |
| Cold Spark Ads | $1.41 CPC @ 2.6% CVR = **~$54 CPA** |
| Skincare CPM | $5–$10 |

Against a **$20** product: $500 at median CPA buys ~39 sales (**$780**, 1.56× ROAS). Cold Spark Ads lose $34 per sale.

**Cold paid advertising cannot produce $10,000 from $500.** The arithmetic does not bend. Paid is an amplifier here, not an engine.

### What actually happens this week

Built up from realistic per-channel contribution rather than backwards from a target:

| Source | Seats | Notes |
|---|---|---|
| Waitlist email | ~50 | **Depends entirely on list size — the dominant unknown** |
| Organic posts | ~30 | 20–25 posts shipped, one modest hit |
| Creators | ~20 | 5 of 10 deliver in-window, better CVR than cold |
| Paid reserve | ~15 | Deployed on a proven winner |
| **Total** | **~115** | **≈$2,300** |

| Scenario | Seats | Revenue | Notes |
|---|---|---|---|
| **Floor** — execution slips, no hits | ~40 | **$800** | |
| **Likely** | **~115** | **$2,300** | 4.6× ROAS |
| **Upside** — one mid hit (100k+) or a large waitlist | ~250 | **$5,000** | |
| **Stretch** — true breakout (1M+) | 500 | **$10,000** | Possible, not plannable |

### Why the earlier $3k floor was too generous

- **Cold accounts underperform the benchmark.** "1 in 20–30 posts clears 100k" describes accounts the algorithm has already classified. Accounts created Wednesday sit at 200–500 views while it figures out who to show them to. Day 1–2 buys classification, not reach.
- **Volume was the mechanism, and volume is capped by one pair of hands.** 55–60 posts is a team's week. §5 fixes this by cutting to a number that actually ships.
- **Creators are slow.** DM → negotiate → brief → film → post. Most land Saturday at the earliest; expect 4–6 of 10 in-window at all.

The distribution is heavily right-skewed. One breakout relocates the entire outcome — that's a real possibility, just not the modal one.

### Funnel reference

```
115 seats ÷ 4.5% landing CVR    = ~2,550 landing sessions
2,550 ÷ 1.0% view→click         = ~255,000 views
```

For the $10k stretch the view requirement is ~1,000,000 — useful mainly as a reminder of what a breakout has to look like.

4.5% CVR is defensible for you: guest checkout with no signup (`api/stripe-checkout.ts:6`), $20 impulse price, demo-first landing, 14-day guarantee. **Each +1% of CVR ≈ $500 at likely volume**, which is why §7 still earns its place.

---

## 2. Day 0 blockers

### ✅ B1 — Seat counter honesty *(fixed)*

`src/hooks/useFoundingCount.ts` previously carried `DISPLAY_BASELINE_CLAIMED = 138`, adding 138 phantom claimed seats to the display. Now removed; the counter shows the true RPC value.

Two notes on why this mattered:

- **The revenue argument is moot at likely volume.** The display would have hit 500 after 362 real sales, flipping `soldOut` (`Landing.tsx:2291`) and unmounting the offer section (`:2543`), hero CTA (`:2371`) and sticky bar (`:3164`) — a hard $7,240 ceiling. At ~115 seats that cap never binds.
- **The honesty argument stands, and is stronger.** A counter reading 253/500 when 115 people bought is a claim a customer can catch, and your first hundred buyers are exactly who watch it move. Fixed on those grounds.

Consequence: the counter now reads low early. That's expected — urgency moves to the price step (B4), which is true and doesn't require inventing buyers.

### ✅ B2 — Real domain *(already done — but not the one this plan assumed)*

A custom domain exists and is live: **`www.skinstel.com`**. The apex `skinstel.com` 308-redirects to `www`. Verified against the Vercel project (`prj_C7Ypb9fuca…`), which lists exactly four domains — `www.skinstel.com`, `skinstel.com`, and two `*.vercel.app` internals.

The URL this plan previously named, `skintel-six.vercel.app`, **does not exist** — it returns `DEPLOYMENT_NOT_FOUND`. It appears to have been carried forward from an early session note and was never a live host. Anything pointing at it (metadata, sitemaps, Stripe webhook endpoints, Supabase Auth redirect URLs) is pointing at nothing.

- [ ] Verify the Stripe webhook endpoint is registered against `www.skinstel.com`, not the dead host. **If it is not, checkout succeeds and the subscription never activates** — the single worst failure mode for this launch.
- [ ] Verify Supabase Auth redirect URLs use `www.skinstel.com/auth/callback`
- [ ] Confirm `appUrl()` resolves to the live host in production

### 🔴 B3 — Name collision: **confirmed, and it is real**

This was listed as "find out Wednesday, not Saturday." Here is Wednesday.

**Every clean `skintel` domain is taken, and at least two are live skincare products with the same name and the same pitch:**

| Domain | Status | Their positioning |
|---|---|---|
| `skintel.app` | Live, pre-launch | "Skincare that learns your skin. One morning selfie…" — iPhone, coming soon |
| `skintel.io` | Live, shipping | "Evidence-based, personalized guidance. No photos needed." |
| `skintel.com` | Registered, not resolving | — |
| `skintel.co` | Registered, erroring (526) | — |
| `getskintel.com` | Registered | — |
| `tryskintel.com` | **Available**, $11.25/yr | — |

**This is a direct hit on §6.** The branded-search mechanic assumes someone who hears "Skintel" and searches it lands on you. They will not. They will type `skintel.com`, or Google "Skintel", and meet two competitors whose domains actually match the name — while yours reads `skinstel.com`, which looks like a typo of the name you just said out loud.

Every view you buy or earn under the spoken name partly subsidises `skintel.app` and `skintel.io`.

Three ways out, in order of cost:

1. **Buy `tryskintel.com` ($11.25) and say "tryskintel.com" on screen instead of a bare name.** Cheapest, keeps the brand, removes the guess. The plan's §6 becomes "say the domain" rather than "say the name" — weaker than pure branded search, but it lands on you.
2. **Spell the domain on screen every time** — `skinstel.com` as plain text for 2 full seconds, and pin it as the first comment. Free, but you are fighting your own name on every single view.
3. **Rename.** Correct long-term if this becomes the real business, far too expensive to do inside this week.

Recommendation: **(1) plus (2)** for this week — $11.25 out of the $35 buffer — and treat the rename question as a post-launch decision informed by whether the week works at all.

Also still to do, and now more urgent:

- [ ] Search "Skintel" on TikTok, IG, YouTube — find out whether the competitors already hold the handles
- [ ] Register one handle and use it identically everywhere

### 🟡 B4 — Price step, not a closing deadline

**Do not announce "the founding batch closes Sunday."** That was built for a sell-out scenario. At ~115 seats it forces a bad choice: kill a working offer at 23% sold, or reopen after publicly committing to close and destroy the credibility the deadline was meant to create.

Use a price step instead:

> **$20 through Sunday. $29 after.**

Same urgency, honorable indefinitely, and the batch stays open. Keep the 500-seat cap as the scarcity story and let price be the clock. Then hold the step — if it's still $20 on Monday, you've taught your first hundred customers your deadlines are decorative.

### 🟡 B5 — Capture every non-buyer

At likely volume ~2,400 people leave without buying. `api/waitlist.ts` already exists. Capture email on exit, send one Sunday "price goes up tonight" email. Warm lists convert 5–15%.

### 🟢 B6 — Already good, don't touch

- Guest founding checkout, no signup wall — `api/stripe-checkout.ts:6`
- `?ref=` attribution into Stripe metadata — `api/stripe-checkout.ts:27,35`
- 14-day guarantee, prominently placed
- Demo-first landing layout

---

## 3. Where the $500 goes

| # | Line item | Amount | Rationale |
|---|---|---|---|
| 1 | **Domain** | **$15** | B2 |
| 2 | **Nano-creator seeding** — 8–10 @ $30–50 | **$300** | 2026 nano rates are $20–100/TikTok video. Pre-qualified audiences, best views-per-dollar available. |
| 3 | **Winner amplification reserve** | **$150** | Hold it. Spark-boost *only* posts already past ~20k views organically. |
| 4 | **Buffer** | **$35** | Contingency |

Boosting a proven organic winner is the one paid play with good odds — the algorithm has already told you the creative works. Spend the reserve Friday or Saturday on evidence, not Wednesday on hope.

**Creator brief** (send verbatim):

> Record your actual routine on camera. Scan it with Skintel. React honestly to what it finds — especially if it flags something you love. Don't script it, don't list features, don't say "link in bio." Say the name once: "Skintel." If it finds nothing interesting, tell me and we won't run it.

Give each creator their own `?ref=` code.

---

## 4. How to actually make this much content

The honest answer: **you are not making 25 videos. You are making 5 templates and refilling them.**

### Batch by stage, never by video

Never take one video end-to-end. Do all filming in one block, all assembly in another. Context-switching between "performer" and "editor" is what kills solo content output.

### The five templates

Three of these require **no filming at all** — screen recording only. That's the unlock.

| Template | Filming? | How fast |
|---|---|---|
| **The Scan** — hold product, scan, react to verdict | Yes | 10 in one 40-min sitting |
| **The Stitch** — react to someone else's routine video | Screen + face | 5 in an hour |
| **The Culprit Reveal** — "these 3 products all contain X" | No | 15 min each |
| **The Comment Reply** — video reply to "what's in my moisturizer?" | No | 10 min each |
| **The Tier List** — rank products on screen | No | 15 min each |

### One filming session produces the week

Wednesday: put 15 products from your own bathroom on the counter, phone propped on a stack of books, film yourself scanning each one in a single continuous session. That's your entire Scan inventory. No script, no retakes unless unusable.

### Hooks are the only thing you write

Write **25 hooks** — just the first 1.5 seconds — in one 30-minute sitting. Highest-leverage half hour of the week. The body of every video is just the scan; the hook is the variable the algorithm actually tests. Same footage + different hook is legitimately a different video.

### Reuse ruthlessly

Any post past ~30k views gets re-cut with 3 new hooks and reposted. That's not lazy, it's the playbook: winning creative deserves more shots, and each recut takes 5 minutes.

### Don't edit

Native camera. Auto-captions (CapCut or TikTok built-in). No music beds, no transitions, no B-roll. Editing is where solo content plans die, and polished content underperforms native content in this niche anyway. **The demo is the content.**

### Cross-post mechanically

Every asset → TikTok, Reels, Shorts, Pinterest. Same file, four placements. Turns 25 videos into 100 placements for zero extra production.

### The real time budget

```
1 filming session          90 min
1 hook-writing session     30 min
25 × ~10 min assembly     250 min
                          ─────────
                          ~6.2 hours across 4 days
```

Achievable solo. Sixty videos was not.

---

## 5. The organic engine

### Volume: 20–25 posts, executed properly

Not 60 half-made ones. A smaller plan shipped fully beats a large plan shipped at 40% — you get more comment replies, better hooks, and the algorithm rewards engagement depth over raw count on a young account.

### Prioritise two formats only

1. **Stitch / duet a large skincare creator's routine** — borrows their entire audience. Highest leverage available to you. Do this daily.
2. **"I scanned my routine and found the ingredient breaking me out"** — the core demo, personal POV.

The other three templates are there to keep accounts active between swings. Drop the generic ingredient explainers entirely — they were padding for a volume strategy you're no longer running.

### The hook that does the work

Your landing already states the insight well:

> *"Your skin isn't broken. Your routine is fighting itself."*

Perfect short-form material: it reframes blame away from the viewer, is surprising, is checkable against their own bathroom shelf, and demands the comment *"what's in mine?"*

### Non-negotiable production rules

- **Hook in the first 1.5 seconds.** No logo, no intro, no "hey guys."
- **Show the scan on screen.** Product → scan → verdict is the whole story.
- **Native, not produced.** Phone camera, real bathroom, real products.
- **Say the name out loud once.** See §6.
- **Reply to every comment for 2h after posting.** Comment velocity is a ranking input and every reply is free reach. This is why 25 posts beats 60.

### ⚠️ Reddit: high value, high risk

r/SkincareAddiction, r/AsianBeauty, r/acne, r/30PlusSkinCare are exactly your buyers, and nearly all ban self-promotion.

**Do not drop links.** A founder caught astroturfing a skincare sub becomes a screenshot that outlives the campaign — asymmetric and permanent. Instead: answer "what's breaking me out?" threads with genuine ingredient analysis, no product mention. Name the tool only when asked. Read each sub's rules. This won't move the needle by Sunday — it's a channel you're starting, not a growth hack.

---

## 6. Making them search it up

Short-form is the #1 ROI format marketers report, and consumers increasingly treat TikTok as a search engine. TikTok's 2026 data showed brands bundling search-side placements saw a **58% increase in search page views** and **42% better CTR**.

### The mechanic

Off-platform links are suppressed and cost reach. A spoken name costs nothing, and a viewer who searches you is far warmer than one who taps a link.

1. **Say the name clearly, once, mid-video.** Never "link in bio" as the CTA.
2. **Let comments do the asking.** "What app is that?" is the highest-value comment you can get.
3. **Put the name on screen** as plain text for 2 seconds.
4. **Keep the bio link live** for the minority who look.

### The dependency people forget

**If people search "Skintel" and find nothing, the campaign is burned.** It is worse than that here — per **B3**, they find *someone else*. `skintel.app` and `skintel.io` are live skincare products under the identical name, and their domains match the word you are saying while yours does not.

So the mechanic above changes: **say the domain, not just the name.** "Skintel — that's skinstel dot com" or, if you buy it, "tryskintel dot com." One extra beat of audio, and it is the difference between your traffic and theirs.

Before the first post:

- [ ] TikTok search → your account, populated with content
- [ ] IG + YouTube → same handle, same avatar
- [ ] Google → `www.skinstel.com` ranks for the *domain* as typed (you will not win "Skintel" this week)
- [ ] TikTok in-app search → several of your own videos, so results look populated
- [ ] App Store → **nothing ships here.** The iOS designs exist (`designs/`) but there's no app. Name the web app in videos, or point explicitly at the site.

---

## 7. Day-by-day

### Wednesday — Day 0: unblock, film, email

- [ ] **Check the waitlist size first.** It's the branch point for the entire week (§9)
- [ ] **Email the waitlist.** Highest-ROI action available, $0 cost
- [ ] Buy + wire domain (**B2**)
- [ ] Claim handles, collision check, populate search results (**B3**, §6)
- [ ] Add price-step copy to hero / offer / sticky bar (**B4**)
- [ ] DM 20–30 nano creators, close 8–10
- [ ] **One filming session** (90 min) + **hook-writing session** (30 min) → §4
- [ ] Test checkout end-to-end with real money, then refund it

### Thursday — Day 1: launch

- [ ] 6–7 posts, cross-posted to Reels + Shorts + Pinterest
- [ ] 2 stitches of large skincare creators
- [ ] Comment replies for 2h after each post
- [ ] Creator briefs + ref codes out
- [ ] Evening: flag anything past 20k views

### Friday — Day 2: double down

- [ ] Re-cut top performer into 3 hook variants
- [ ] 6–7 posts
- [ ] **Deploy $150 reserve on proven winners only**
- [ ] Mid-day check against §8

### Saturday — Day 3: peak

Weekend is peak skincare engagement.

- [ ] 6–7 posts, heaviest day
- [ ] Video replies to top comments (compounding format)
- [ ] Remaining creators post

### Sunday — Day 4: close the price

- [ ] **Last-call email to every captured non-buyer** — biggest single event of the day
- [ ] "Price goes up tonight" content
- [ ] Final push 6–10pm
- [ ] **Step the price to $29 at midnight, as promised**

---

## 8. Tracking and kill criteria

Check twice daily: **views → sessions → checkout starts → sales**, split by `?ref=`.

| Symptom | Read | Action |
|---|---|---|
| Views low (<10k/day) | Hooks aren't landing | Rewrite first 1.5s — new hooks, not new edits |
| Views fine, clicks low | Name/CTA unclear | Say name earlier, add on-screen text |
| Clicks fine, sales low | Landing mismatch | Fix message-match first |
| Paid CPA > $15 | Cold ads underwater | Kill same day |

**Hard rule:** paid CPA over $15 for 24h → stop that spend immediately. On a $20 product it's losing money, and the reserve is worth more held than spent.

---

## 9. The week's real KPI

500 seats was always a stretch. What's reliably obtainable for $500 in four days is **knowing which hook converts** — and that's the asset that makes next month's launch work.

Tag every post and creator with `?ref=`; the plumbing already exists. By Sunday you'll know which angle earns attention and which earns money.

115 founding users is not a failed week for a pre-launch product. It's ~4.6× ROAS, and the cohort is worth more than the $2,300: it tells you which ingredients and triggers people care about, which hooks convert, and it sets up a renewal decision in November at $9/mo worth multiples of the founding revenue.

### If you only do six things

1. **Check the waitlist size before anything else** — it changes how you spend the week. Large list: front-load email, treat content as upside. Small list: content is the only engine.
2. **Buy the domain today.** $15. The search strategy fails on a `.vercel.app`.
3. **Price step, not a closing deadline.** Never announce a close you'd have to walk back.
4. **Don't put $500 into cold ads.** Median CPA is $12.80 against a $20 product.
5. **5 templates, not 25 videos.** One filming session, 25 hooks, no editing.
6. **Expect ~$2,300, stay ready for more.** A breakout is possible, not plannable.

---

## Appendix — assumptions

| Assumption | Value | Basis |
|---|---|---|
| Landing CVR (warm short-form) | 4.5% | Guest checkout, $20 price, guarantee. Range 2–6%. |
| View → click rate | 1.0% | Typical 0.5–1.5% for spoken-name + bio-link |
| Posts actually shipped | 20–25 | Solo capacity over 4 days (§4) |
| Creators delivering in-window | 5 of 10 | Nano creator latency |
| Nano creator rate | $30–50/post | 2026 range $20–100 |

**Unverified — check before relying on these:** current waitlist size (Supabase couldn't be queried from the authoring session; the MCP connection needs authorization), real founding seats sold to date, and whether "Skintel" collides with an existing brand.

---

## Sources

- [Skincare Advertising Benchmarks 2026 — Meta, TikTok & Google ROAS, CPM & CPA](https://www.pennock.co/blog/skincare-advertising-benchmarks-2026-meta-tiktok-amp-google-roas-cpm-amp-cpa-data-for-dtc-skincare-brands)
- [TikTok Ads Cost 2026: CPM, CPC & CPA Benchmarks](https://benly.ai/learn/tiktok-ads/tiktok-ads-cost-benchmarks)
- [TikTok Ads Benchmarks by Industry (2026 Data)](https://hawky.ai/blog/tiktok-ads-benchmarks)
- [Beauty & Skincare TikTok Ads Statistics](https://www.webtonic.io/blog/beauty-skincare-tiktok-ads-statistics)
- [Nano Influencer Rates — 2026 Cost Guide](https://influencermarketinghub.com/influencer-rates/nano-influencer-rates/)
- [TikTok Influencer Rates in 2026](https://influencermarketinghub.com/influencer-rates/tiktok-influencer-rates/)
- [TikTok's Branded Buzz and Search Hubs connect creator content to search](https://ppc.land/tiktoks-branded-buzz-and-search-hubs-connect-creator-content-to-search/)
- [How Short-Form Video Is Reshaping Brand Discovery](https://selectedfirms.co/blog/short-form-video-brand-discovery)
