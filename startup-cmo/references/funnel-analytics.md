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
- **Deduplicate milestone events:** Emit one-time milestones (`User Activated`, `User Engaged`, `Subscription Started`, `Referral Prompted`) at most once per user/conversion (backed by a KV flag or DB check) so retries never inflate conversion counts.

## Auditing Spikes & Anomalies

When an anomaly detector or dashboard shows a sudden spike (e.g. `Quota Exceeded` jumping 5x while paid conversions look flat):

1. **Check concentration first:** Group by `distinct_id` and `botId`/`workspaceId` over the last 48h. Often 60%-80% of a spike comes from 1-2 accounts (a runaway background job, an expired integration receiving third-party webhooks/messages, or a recent identity-stitching deploy rolling many sender IDs onto one owner ID).
2. **Check conversion on the real denominator:** Compute `paid / unique_eligible_capped_users` and `referred / unique_eligible_capped_users` over 14d-30d rather than `paid / raw_paywall_events`.
3. **Inspect the actual transcripts of the top 5 capped users:** Look at *when* they hit the cap (Day 1 vs. Day 7), *what* they were trying to do, and *what message* they saw.

## Executive Scorecard Cadence

Send the founder a concise automated weekly scorecard covering:

- Active paying customers (total + breakdown by tier + net delta vs. prior week).
- 7-day cohort progression: Real signups -> Activated -> Engaged -> New paid.
- Top entry points: Raw visitors + conversion rate per surface (`landing`, `demo`, `blog`, `pricing`).
- Growth loops: Referrals prompted -> rewards granted -> referred signups.
- Biggest leak of the week + the single experiment or fix prioritized next.
