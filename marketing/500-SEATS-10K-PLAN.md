# Skintel — 500 Founding Seats / $10,000 / $500 Budget

**Window:** Wed 12 Aug → Sun 16 Aug 2026 (4.5 days)
**Offer:** 3 months of Pro for $20, one-time, no auto-renew. 500 seats.
**Target:** 500 × $20 = $10,000
**Budget:** $500

---

## 1. The honest math first

Read this before spending a dollar, because it determines where the $500 goes.

### $10,000 from $500 is 20× ROAS. That is a $1.00 CPA.

Current benchmarks for this exact vertical:

| Metric | Benchmark | Source |
|---|---|---|
| DTC beauty median CPA, TikTok | **$12.80** (IQR $7.40–$21.10) | AdLiftr 2026 |
| Beauty CPC, TikTok | $0.60–$0.90 | 2026 benchmarks, down 22% YoY |
| Spark Ads (boosted creator content) | $1.41 CPC @ 2.6% CVR = **~$54 CPA** | 2026 benchmarks |
| Skincare CPM | $5–$10 | 2026 benchmarks |

Against a **$20** product:

- $500 at median $12.80 CPA → **39 sales → $780**. ROAS 1.56×.
- $500 at best-case $7.40 CPA → **67 sales → $1,350**. ROAS 2.7×.
- Cold Spark Ads at $54 CPA → **you lose $34 per sale**.

**Cold paid advertising cannot produce $10,000 from $500.** Not with better creative, not with better targeting. The arithmetic does not bend. Anyone promising otherwise is selling something.

### So what does produce $10,000?

Organic short-form video, at volume, with paid used only as an amplifier on proven winners.

Work the funnel backwards:

```
500 seats needed
 −  45 from paid/creator-attributed        (realistic paid contribution)
 = 455 from organic

455 sales ÷ 4.5% landing conversion         = ~10,100 landing sessions
10,100 sessions ÷ 1.0% view→click rate      = ~1,000,000 views
```

**The real target is ~1,000,000 organic views in 4.5 days.** Every tactic below is judged against that single number.

The 4.5% landing CVR is defensible for you specifically — guest checkout with no signup (`api/stripe-checkout.ts:6`), $20 impulse price, demo-first landing, 14-day guarantee. Most $20 offers convert 2–3%; yours should beat that. Each +1% of CVR is worth **~$2,200** at these traffic volumes, which is why §7 matters as much as §5.

### Realistic outcome tiers

State these up front so the week is judged fairly:

| Scenario | Views | Seats | Revenue | Probability |
|---|---|---|---|---|
| **Floor** — plan executed, no breakout | ~250k | ~150 | **$3,000** | ~60% |
| **Base** — 2–3 posts clear 100k | ~500k | ~265 | **$5,300** | ~30% |
| **Goal** — one true breakout (≥1M) or several 300k+ | 1M+ | 500 | **$10,000** | ~10% |

$10k requires a breakout. Breakouts cannot be summoned, only made more likely — by shipping enough shots on goal, with hooks engineered to trigger the algorithm. The plan below maximizes the number and quality of those shots.

Note the floor case is still **6× ROAS and 150 founding users**. That is a good week by any normal standard. Do not let the $10k number make a $3k week feel like failure.

---

## 2. Day 0 blockers — fix before spending anything

These are not optimizations. Each one silently caps revenue.

### 🔴 B1 — The seat counter caps you at $7,240

`src/hooks/useFoundingCount.ts:4`

```ts
const DISPLAY_BASELINE_CLAIMED = 138;
```

The displayed count is `138 + actual_claimed`. It reaches 500 after **362 real sales**. At that moment `soldOut` becomes true (`Landing.tsx:2291`) and:

- the entire founding offer section unmounts — `Landing.tsx:2543`
- the hero CTA flips to sold-out copy — `Landing.tsx:2371`
- the sticky bottom bar says "Founding batch sold out" — `Landing.tsx:3164`

Checkout still functions (the API reads the true RPC value), but no visitor can reach it. **Hard ceiling: 362 × $20 = $7,240.** The last $2,760 of your goal is unreachable.

It is also a fabricated claim to consumers — 138 people who did not buy, presented as buyers. That is a straightforward deception risk, and it is the kind of thing that becomes a story if a customer screenshots the counter on day 1 and day 3 and sees it move wrong.

**Fix:** set the baseline to `0`. Replace the lost urgency with things that are true:

- a real deadline — "founding batch closes Sunday 11:59pm" (see B4)
- your real waitlist size — "1,4XX on the list · 500 seats" is stronger than a fake counter, and true
- real velocity once it exists — "37 claimed in the last 24h"

An honest counter that starts slow is a smaller problem than a dishonest one that stops your revenue at 72% of goal.

### 🔴 B2 — `skintel-six.vercel.app` breaks the entire "make them search it" strategy

This is the highest-leverage $15 in the plan. §6 depends on ~1M people hearing the name and searching it. When they do, they must land on something that looks like a company.

- Buy `skintel.app` / `getskintel.com` / `skintel.io` — whichever is free, today, ~$12–15
- Point it at Vercel, update `appUrl()` and Supabase Auth redirect URLs
- A `.vercel.app` subdomain in a TikTok comment reads as a scam link. It will cost you more than 1% CVR, which is more than $2,000.

### 🔴 B3 — Claim the name everywhere, and check for collisions

Before you drive a million searches to a name, spend 10 minutes confirming the name is yours to own:

- Search "Skintel" on TikTok, Instagram, YouTube, Google, App Store. Note what currently ranks.
- Register `@skintel` (or `@skintelapp` / `@getskintel` — pick one and use it identically everywhere) on TikTok, IG, YouTube, Reddit, Pinterest.
- If a bigger brand already owns the term, that changes your hook — you'd drive searches straight to a competitor. Find out now, not on Saturday.

### 🟡 B4 — Add a real deadline

The offer currently has seat scarcity but no time pressure, so there is no reason to buy *today*. A week-long sprint needs a week-shaped deadline.

Add "Founding batch closes Sunday 11:59pm PT" to the hero, offer section, and sticky bar. Seat scarcity plus time scarcity converts far better than either alone.

**Then actually honor it.** If you extend it, the scarcity was a lie and you have taught your first 200 customers not to believe you. Either close it Sunday or don't claim you will.

### 🟡 B5 — Capture every non-buyer

At 10,000 sessions and 4.5% CVR, **9,550 people leave without buying**. The waitlist endpoint already exists (`api/waitlist.ts`). Make sure the exit path captures email, and send one Sunday-morning "last call" email. Email to a warm list converts at 5–15%. If you capture even 1,500 emails, that final send is worth **$1,500–$4,500** on its own — the single highest-ROI action of the week, at $0 cost.

### 🟢 B6 — Already good, don't touch

Worth knowing what's working so you don't "improve" it mid-sprint:

- Guest founding checkout with no signup wall — `api/stripe-checkout.ts:6`. Removes the biggest drop-off in the funnel. Keep it.
- `?ref=` attribution already flows into Stripe metadata — `api/stripe-checkout.ts:27,35`. Creator tracking is already built (see §4).
- 14-day money-back guarantee, prominently placed. Keeps CVR up on cold traffic.
- Demo-first landing layout. Correct for this product.

---

## 3. Where the $500 actually goes

Not into cold ads. Into leverage.

| # | Line item | Amount | Rationale |
|---|---|---|---|
| 1 | **Domain** | **$15** | B2. Highest ROI dollar in the plan. |
| 2 | **Nano-creator seeding** — 8–10 creators @ $30–50 | **$300** | Nano rates (1–10k followers) are $20–100/TikTok video in 2026. Their audiences are pre-qualified and trust them. Best views-per-dollar available. |
| 3 | **Winner amplification reserve** | **$150** | Hold it. Spark-boost *only* posts that already cleared ~20k views organically in 24h. Never boost cold creative. |
| 4 | **Buffer** | **$35** | Scheduling tool, thumbnail assets, contingency. |

**Why the reserve matters:** boosting a proven organic winner is the one paid play with genuinely good odds, because the algorithm has already told you the creative works. Boosting cold creative at $54 CPA loses money on a $20 product. Spend the $150 on Friday or Saturday, on evidence — not on Wednesday, on hope.

**Creator brief** (send verbatim, it's what makes $30 posts perform):

> Record your actual routine on camera. Scan it with Skintel. React honestly to what it finds — especially if it flags something you love. Do not script it, do not read a list of features, do not say "link in bio." Say the name once: "Skintel." If it finds nothing interesting, tell me and we won't run it.

Give each creator their own `?ref=` code so you can see exactly who delivered. That data is worth more than this week's sales — it tells you who to scale with next month.

---

## 4. The organic engine — how 1M views gets made

### Volume plan

**3 accounts × 4–5 posts/day × 4 days ≈ 55–60 posts.**

Why three accounts: the algorithm's per-post variance is enormous and largely independent. Sixty posts is sixty lottery tickets. A single account posting 4×/day also risks looking spammy; three themed accounts (main brand, "routine reviews," "ingredient facts") each look native.

Expected distribution on a well-targeted niche account: median post 200–2,000 views, roughly 1 in 20–30 posts clears 100k. Sixty posts should yield **2–3 posts over 100k** and one real shot at 500k+.

### The hook that does the work

Your product has a genuinely non-obvious, emotionally loaded insight, and the landing page already states it well:

> *"Your skin isn't broken. Your routine is fighting itself."*
> *"The same ingredient is hiding across multiple products — that's what's breaking you out."*

This is perfect short-form material because it (a) reframes blame away from the viewer, (b) is surprising, (c) is immediately checkable against their own bathroom shelf, and (d) demands a comment: *"what's in mine?"*

### Nine formats, ranked by expected reach

1. **Stitch / duet a big skincare creator's routine video** — scan their products live, react. Borrows their entire audience. *Highest leverage available to you. Do this daily.*
2. **"I scanned my whole routine and found the one ingredient breaking me out"** — screen recording, personal, POV.
3. **"Your $200 routine is fighting itself"** — scan an expensive influencer routine, show the conflict.
4. **"Rate my routine"** — reply to comments *as video replies*. Each reply is a new post with the original's engagement attached. Compounding.
5. **Red flag / green flag product tier list** — endlessly remixable, high save rate.
6. **"3 products everyone owns that share the same pore-clogging ingredient"** — listicle, high completion rate.
7. **"This 'clean' product contains ___"** — myth-bust. Controversial, drives comments.
8. **Before/after culprit reveal** — needs a real user story. Highest converting, lowest supply.
9. **Ingredient-fact micro-explainers** — filler content that keeps accounts active between swings.

### Non-negotiable production rules

- **Hook in the first 1.5 seconds.** No logo, no intro, no "hey guys." Start mid-sentence on the most surprising claim.
- **Show the scan on screen.** The demo *is* the ad. Product-in-hand → scan → verdict is the whole story.
- **Native, not produced.** Phone camera, real bathroom, real products. Polished ads get scrolled past; this is the single most common failure mode for a founder-made skincare video.
- **Say the name out loud once.** See §6.
- **Reply to every comment for the first 2 hours.** Comment velocity is a ranking input, and every reply is free reach.

### Where else to post

- **Instagram Reels + YouTube Shorts** — same vertical asset, zero extra production cost. Always cross-post.
- **Pinterest** — skincare performs unusually well and traffic is evergreen, unlike TikTok. Low effort, keeps paying after Sunday.
- **Reddit** — see the warning below.

### ⚠️ Reddit: high value, high risk of backfire

r/SkincareAddiction, r/AsianBeauty, r/acne, r/30PlusSkinCare, r/tretinoin are exactly your buyers, and nearly all of them ban self-promotion.

**Do not drop links.** A promo post gets removed in minutes, and a founder caught astroturfing a skincare sub becomes a screenshot that outlives the campaign — that risk is asymmetric and permanent.

**Do this instead:** answer "what's breaking me out?" threads with genuine, specific ingredient analysis. Be actually useful with no mention of the product. Name the tool only when someone asks what you used. Read each sub's rules first; several permit a flaired self-promo day. This is slow and won't move the needle by Sunday — treat it as a real channel you're starting, not a growth hack.

---

## 5. Making them search it up

This is the mechanic you specifically asked about, and it's the right instinct — short-form video is now the #1 ROI format marketers report, and consumers increasingly treat TikTok as a search engine. TikTok's own 2026 data showed brands bundling search-side placements saw a **58% increase in search page views** and **42% better CTR**.

### The mechanic

Off-platform links are suppressed and cost you reach. A spoken brand name costs nothing, and a viewer who searches your name is a far warmer visitor than one who taps a link.

1. **Say the name clearly, once, mid-video.** Never "link in bio" as the call to action.
2. **Let the comments do the asking.** "What app is that?" is the highest-value comment you can get — it drives engagement *and* signals intent. Reply to every one with just the name.
3. **Put the name on screen** as a plain text overlay for 2 seconds.
4. **Keep the bio link live anyway** for the minority who look.

### The dependency nobody remembers until it's too late

**If 1M people search "Skintel" and find nothing, you have burned the entire campaign.** Before any volume posting starts, all of the following must return you:

- [ ] TikTok search "skintel" → your account, verified-looking, with content
- [ ] Instagram + YouTube search → same handle, same avatar, same bio
- [ ] Google "skintel" → your real domain (**B2**), indexable, with a title tag that says what it is
- [ ] TikTok in-app search → several of your own videos, so the results page looks populated
- [ ] App Store "skintel" → currently **nothing ships here.** The iOS designs exist (`designs/`) but there's no app. Anyone searching the App Store finds nothing. Make sure the web app is what you name in videos, or point explicitly at the site.

This checklist is Day 0, before the first post. Driving a million searches into an empty results page is the most expensive mistake available this week.

---

## 6. Day-by-day

### Wednesday 12 Aug — Day 0: unblock (no posting yet)

Nothing on this list is optional, and all of it is same-day work.

- [ ] Fix `DISPLAY_BASELINE_CLAIMED = 138` → `0` (**B1**)
- [ ] Buy + wire domain (**B2**)
- [ ] Claim handles, run collision check, populate search results (**B3**, **§5 checklist**)
- [ ] Add Sunday deadline to hero / offer / sticky bar (**B4**)
- [ ] **Email the existing waitlist.** Highest-ROI action of the week, $0 cost, do it first.
- [ ] DM 20–30 nano creators; aim to close 8–10 at $30–50
- [ ] Batch-film 20 videos. Front-load production so posting never blocks on filming.
- [ ] Confirm analytics: Vercel Analytics is live (commit `793fde0`); verify `?ref=` lands in Stripe metadata

### Thursday 13 Aug — Day 1: blitz

- [ ] 12–15 posts across 3 accounts, cross-posted to Reels + Shorts
- [ ] 2 stitches of large skincare creators
- [ ] Reply to every comment for 2h after each post
- [ ] Creator briefs + ref codes out
- [ ] **Evening: identify anything over 20k views**

### Friday 14 Aug — Day 2: double down

- [ ] Re-cut the top performer into 3 variants — same hook, different openings. If a hook works, mine it.
- [ ] 12–15 posts
- [ ] First creator posts land
- [ ] **Deploy $150 reserve on proven winners only**
- [ ] Mid-day revenue check against §8 kill criteria

### Saturday 15 Aug — Day 3: peak

Weekend is peak skincare engagement. Highest-volume day.

- [ ] 15 posts, heaviest push
- [ ] Video replies to top comments (compounding format)
- [ ] Push seat count in copy if — and only if — the real number is genuinely compelling
- [ ] Remaining creators post

### Sunday 16 Aug — Day 4: close

- [ ] **Last-call email to every captured non-buyer** (B5) — biggest single revenue event of the day
- [ ] "Closes tonight" content all day
- [ ] Final push 6–10pm
- [ ] **Close the offer at 11:59pm as promised**

---

## 7. Conversion work — worth more than the ad budget

At ~10,000 sessions, **every +1% of CVR ≈ $2,200**. That is 4× your entire budget, which is why these are not afterthoughts.

- **Match the landing to the video.** Traffic from "the ingredient breaking you out" must land on that exact claim above the fold. Message-match is the largest single CVR lever.
- **Keep guest checkout.** No signup before payment. Already correct — protect it.
- **Guarantee stays visible** at the CTA, not in the footer.
- **Mobile-first.** ~95% of this traffic is a phone in one hand. Test the full flow on a real phone before Thursday.
- **Test checkout end-to-end with real money today.** A broken Stripe flow on Saturday night is the only failure that costs you the entire week. Buy one seat yourself and refund it.

---

## 8. Tracking and kill criteria

Check twice daily: **views → landing sessions → checkout starts → completed sales**, split by `?ref=`.

Diagnose by where the funnel actually breaks:

| Symptom | Read | Action |
|---|---|---|
| Views low (<20k/day) | Hooks aren't landing | Rewrite first 1.5s. New hooks, not new edits. |
| Views fine, clicks low | Name/CTA unclear | Say name earlier; add on-screen text |
| Clicks fine, sales low | Landing or price mismatch | Fix message-match first, then offer framing |
| Paid CPA > $15 | Cold ads underwater | Kill immediately. Move budget to creators. |

**Hard rule:** if paid CPA exceeds $15 for 24h, stop that spend the same day. On a $20 product it is losing money, and the reserve is worth more held than spent.

---

## 9. What I'd tell you if you only read one section

1. **Fix the 138 counter today.** It caps you at $7,240 and it's a fabricated claim. Everything else is moot until this is done.
2. **Buy the domain today.** $15. The whole search strategy fails on a `.vercel.app`.
3. **Don't put $500 into cold ads.** The vertical's median CPA is $12.80 against a $20 product. Creators + a held amplification reserve beat it decisively.
4. **The number that matters is ~1M organic views.** Post 55–60 times, stitch big creators daily, and treat every post as a lottery ticket.
5. **Email the waitlist first and last.** Free, warm, highest-converting traffic you have — Wednesday morning and Sunday morning.
6. **Expect $3–5k, play for $10k.** $10k needs a breakout. The plan maximizes the odds of one; it cannot guarantee it. A $3k floor on $500 spend is still a 6× week and 150 founding users.

---

## Appendix — assumptions

Stated so you can challenge them rather than inherit them:

| Assumption | Value | Basis |
|---|---|---|
| Landing CVR (warm short-form traffic) | 4.5% | Guest checkout, $20 impulse price, guarantee. Typical range 2–6%. |
| View → click rate | 1.0% | Typical 0.5–1.5% for spoken-name + bio-link |
| Posts clearing 100k views | 1 in 20–30 | Niche account with strong hooks |
| Paid contribution | ~45 sales | $500 at benchmark CPA, creator-weighted |
| Nano creator rate | $30–50/post | 2026 nano range $20–100 |

**Unverified — check before relying on these:** current waitlist size (couldn't query Supabase from this session; the MCP connection needs authorization), real founding seats sold to date, and whether "Skintel" collides with an existing brand.

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
