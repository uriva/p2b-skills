# Funnel Analytics & Diagnostics

## Canonical Funnel Architecture

Every SaaS growth system needs one shared, pinned funnel view keyed on a single canonical user ID (the database primary user ID), covering six stages:

1. **Entry Visit (by entry point & referring domain):** Homepage, dedicated product landing pages, blog posts, zero-auth demos, pricing page.
2. **Primary CTA Click (by exact UI slot):** Track slot locations explicitly (`hero`, `mobile_sticky_bar`, `top_strip`, `bottom_cta`, `interactive_demo`, `blog_post_cta`, `pricing_card`) so you know which page elements actually drive action.
3. **Real Signup:** Filter out bots, unactivated guest shells, and synthetic test accounts. Count only users with a real identity, created resource, or recorded usage.
4. **Activation:** The earliest concrete moment the user got real output (for example, `3+` real runs or completing core onboarding).
5. **Deep Engagement:** Habit formation (for example, `20+` runs or returning on `2+` distinct days).
6. **Monetization & Expansion:** `Quota Exceeded` / paywall hit -> `/pricing` visit -> checkout start -> `Subscription Started` (plus referral rewards granted).

## Critical Instrumentation Rules

- **Never key server-side events on raw channel IDs:** A classic analytics trap is emitting web events under `$users.id` while emitting server-side paywall/usage events under a raw phone number, email address, or chat handle. That silently severs `Paywall -> Paid` funnels. Always resolve and attach the canonical user ID as `distinctId`, storing channel-native IDs in event properties.
- **Segment by referring domain before judging conversion:** A drop in overall landing-page conversion from `20%` to `11%` often means nothing broke — a burst of cold social traffic (`t.co`, `reddit.com`) converted at `5%` while organic search (`google.com`) still converted at `40%-50%`. Always break down conversion by referring domain before touching the page.
- **Monitor frontend and auth errors beside every funnel:** Always pull `$exception`, `Signin Error`, and checkout errors scoped to your money pages (`/pricing`, `/login`, landing pages, demos) in every cycle. A single unhandled WebView error (like `NotAllowedError` on clipboard copy or a race condition on tokenized auth links) silently kills conversions.
- **Emit explicit SPA `$pageview` events when `autocapture` is off:** On client-side routers (Preact/React/Next SPA), disabling analytics autocapture often stops `$pageview` from firing on client-side navigations (`/` -> `/app` -> `/pricing?src=...`), hiding mobile pricing traffic and `?src=` CTA attribution. Fire `$pageview` explicitly on route changes.
- **Verify build-time analytics keys in the live deployed JS bundle:** Seeing analytics SDK initialization in source code does not prove frontend events are firing. Check CI/CD build env vars and grep the live deployed frontend bundle for the project token — a missing `VITE_*` / `NEXT_PUBLIC_*` build secret silently zeroes out 100% of pageview and referrer tracking while backend events still appear healthy.
- **Deduplicate milestone events:** Emit one-time milestones (`User Activated`, `User Engaged`, `Subscription Started`, `Referral Prompted`) at most once per user/conversion (backed by a KV flag or DB check) so retries never inflate conversion counts.
- **Separate unclicked checkout links from real checkout opens:** Never eagerly mint expiring Stripe Checkout sessions inside passive upsell messages or LLM upgrade tools — they pollute open-session metrics (`hasCustomerDetails: false`) and hide true click-through rate. Log distinct stages (`Upgrade Link Offered` -> `Upgrade Link Clicked` -> `Subscription Checkout URL Generated` -> `Paid`) with preserved `source` attribution across the redirect.
- **Count passive consumption in active-user & retention metrics:** On products that deliver value via digests, alerts, or shared links, users who click outbound shortlinks or swipe/interact without typing a new message or logging in are genuinely active. Record `lastLinkClickAt` / passive interaction timestamps alongside inbound messages in WAU/MAU and inactivity-cutoff logic — otherwise your happiest digest readers get undercounted and auto-unsubscribed.
- **Isolate multi-product billing accounts:** When one Stripe account serves multiple founder products, filter every MRR query, checkout list, webhook handler, and dunning email strictly to the product's price IDs or explicit `metadata.product` tag.
- **Never defer analytics behind idle callbacks when attribution params are present:** Lazy-loading PostHog after `load` + `requestIdleCallback` (1.8-3s) drops both landing pageviews and UTM attribution whenever visitors click a hero CTA quickly. When `utm_*`, `gclid`, or `ref` params appear in `location.search`, persist them to `localStorage` immediately, initialize analytics eagerly, forward the query string across internal CTA links, and attach stored attribution onto `User Signed Up`, activation, and purchase events.
- **Keep high-frequency backend ops telemetry out of product analytics quotas:** Sending per-message, per-webhook, or per-API-request operational events into a shared product analytics project quickly exhausts free-tier monthly allowances across sibling apps and blinds conversion funnels. Reserve product analytics for user/funnel milestones and keep high-frequency ops telemetry in logs, metrics, or sampled pipelines.
- **Capture self-reported discovery inside conversational onboarding:** Dark-social referrals (WhatsApp groups, peer recommendations, offline mentions) arrive as `$direct` with no UTM or HTTP referrer. Have your onboarding flow or assistant naturally ask and store self-reported attribution once per user (refusing overwrites and stripping internal prefixes).
- **Judge paid acquisition strictly by real CAC vs. 12-month LTV:** Measure paid spend against attributed paying customers (never raw clicks or unverified signups). When CAC exceeds 12-month LTV, pause the campaign immediately to protect cash flow and reallocate effort to $0-CAC organic and ecosystem loops.
- **Separate internal dogfooding volume from external customer activation:** High headline API volume (e.g. hundreds of thousands of events/month) often comes from one internal founder workspace and can mask 0% external activation. Always segment accounts, tokens, and active usage into `internal` vs `external` in your recurring telemetry script.
- **Trace recurring dashboard timeouts to unbounded nested queries:** Clusters of `"Request timed out"` errors on admin, groups, or settings pages frequently trace to one unbounded parent-to-children client query on high-volume accounts. Replace unbounded nested loads with bounded, ordered, retryable queries before blaming database infrastructure.

## Auditing Spikes & Anomalies

When an anomaly detector or dashboard shows a sudden spike (e.g. `Quota Exceeded` jumping 5x while paid conversions look flat):

1. **Check concentration first:** Group by `distinct_id` and `botId`/`workspaceId` over the last 48h. Often 60%-80% of a spike comes from 1-2 accounts (a runaway background job, an expired integration receiving third-party webhooks/messages, or a recent identity-stitching deploy rolling many sender IDs onto one owner ID).
2. **Check conversion on the real denominator (and count total positive action):** Compute both `paid / unique_eligible_capped_users` and `referred / unique_eligible_capped_users` over 14d-30d rather than `paid / raw_paywall_events`. When a product pairs paid upgrades with a viral free-unlock referral path, track **total positive paywall action (`paid + referral unlocks`)** — a paywall showing `~10%` direct paid conversion may actually be driving `40%+` positive action while feeding fresh signups.
3. **Inspect the actual transcripts and pricing paths of the top 5 capped users:** Look at *when* they hit the cap (Day 1 vs. Day 7), *what* they were trying to do, *what message* they saw, and whether they visited `/pricing` or hit `?checkout=cancelled`. Heavy paywall hits from a user who completed a full multi-day trial, opened checkout, and checked their referral options is often a high-intent delayed buyer rather than noise.

## Executive Scorecard Cadence

Send the founder a concise automated weekly scorecard covering:

- Active paying customers (total + breakdown by tier + net delta vs. prior week).
- 7-day cohort progression: Real signups -> Activated -> Engaged -> New paid.
- Top entry points: Raw visitors + conversion rate per surface (`landing`, `demo`, `blog`, `pricing`).
- Growth loops: Referrals prompted -> rewards granted -> referred signups.
- Biggest leak of the week + the single experiment or fix prioritized next.
