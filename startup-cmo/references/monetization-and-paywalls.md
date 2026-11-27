# Monetization, Trial Pacing & Paywalls

## Protect the Multi-Day Habit (Anti-Day-1 Burnout)

One of the highest-impact SaaS conversion killers is advertising a multi-day free trial (e.g., "7-day free trial") while allowing a single expensive action to exhaust all trial credits in 10 minutes on Day 1.

- **Why it kills conversion:** When a user's very first real task aborts mid-deliverable with `"out of credits"`, they feel tricked instead of delighted. Users who pace naturally across 5-7 real days build a daily habit and convert — even in lower-ARPU regions.
- **The systemic fix:**
  - Put sensible **per-24h burst caps** on high-multiplier actions for Free accounts (for example, capping generated images, outbound phone calls, or heavy compute bursts to ~15%-20% of total trial credits per day) using atomic rate limiting safe under parallel calls.
  - Pre-check remaining credits *before* firing expensive external APIs across all tiers.
  - When a burst cap triggers mid-task, return a clear, constructive tool/system message guiding the product to **finish and deliver the user's result cleanly** using what was already created (e.g. existing assets + clean layout/text) instead of crashing the task, while briefly noting higher limits on paid plans.
  - Stop background/child jobs from enqueueing doomed continuation slices once quota is already exhausted — finalize cleanly and avoid duplicate paywall alerts.

## Trial Structure & Abuse Resistance

- **Non-consecutive active days beat rigid calendar timers:** For products people try intermittently, counting active usage days (e.g. 7 active days) gives real prospects enough time to reach their aha moment without expiring while they were busy for a week.
- **Gate generous free tiers on a real friction-appropriate identity signal:** Keep unverified/anonymous usage tight (enough to feel the product, too small for abuse farms) and unlock the full trial upon verified phone or equivalent strong identity — while pooling unverified usage across shared IP / canonical email aliases to stop disposable-account rotation.
- **Never give away the full quota for weak signals:** Do not expand free caps for trivial email-only signups if disposable emails are being farmed.

## Match Pricing Model to Actual Usage Cadence

- **Check multi-month retention before betting everything on subscriptions:** Query 90-day active usage by distinct active months. When 80%-95%+ of users are episodic (e.g., 1-month searchers/creators), a subscription-only paywall turns away willing buyers.
- **Hybrid Pay-As-You-Go Credit Packs + Monthly Pro:** Offer non-expiring one-time Credit Packs right above Monthly Pro tiers. Packs capture episodic buyers with zero recurring-billing fear while anchoring the per-unit discount of Monthly Pro for power users.
- **Recover involuntary churn (`payment_failed`) immediately:** Audit Stripe cancellations by reason (`payment_failed` vs `cancellation_requested`) and `past_due` counts — involuntary churn routinely drives 50%-70%+ of early-stage MRR loss. Wire a deduplicated `invoice.payment_failed` webhook handler (scoped strictly to the product's price IDs) that emails a 1-click Billing Portal recovery link, and verify the event is actually enabled on the live Stripe webhook endpoint.

## Zero-Friction Paywall & Checkout UX

- **Use signed, non-expiring on-demand upgrade redirects:** Instead of eagerly generating 24h-expiring Stripe Checkout sessions on result delivery, embed HMAC-signed `/api/upgrade?...` links that track clicks and create a fresh Checkout session only on click.
- **Put 1-click checkout buttons directly inside peak-intent friction states:** Never leave dead-end text (`"Top up $5 in your dashboard to unlock"`) on a blocked feature, paused/frozen resource, or insufficient-balance creation error. Render an inline 1-click Stripe checkout button right inside that exact alert or row so users upgrade at peak urgency without hunting for a billing section.
- **Authenticated 1-tap upgrade links:** Every paywall message delivered in chat, email, or in-app should preserve auth or user email so the user lands ready to pay in one click.
- **Add trust reassurance directly on Stripe Checkout:** Set `custom_text.submit.message` right above the Stripe Pay button matching the exact product (`"One-time payment, no subscription. Credits never expire and activate instantly."` vs `"Cancel anytime in 1 click."`).
- **Match sign-in, cancelled-checkout, and success copy to the chosen plan:** Never show `"Sign in to complete subscription"` or `"Subscription confirmed!"` to a buyer who selected a one-time Credit Pack.
- **Keep in-chat upgrade replies punchy (2-3 lines):** When a user triggers a paywall or clicks a watermark-removal button, never dump a 6-bullet wall of text that buries the checkout link. Lead with the 1-click checkout link for the lowest-friction option, mention alternatives in 1 brief line, and give an explicit post-checkout next step (e.g. a clickable `"Re-download without watermark"` button).
- **Guard auth-in-flight states:** On `/pricing?token=...`, never let an unauthenticated render flash a "Sign in to upgrade" wall or redirect to `/login` before the token exchange finishes.
- **Support channel-native checkout:** If a user signed up via WhatsApp/Telegram/phone without linking an email address, allow Stripe Checkout without requiring a pre-linked email (Stripe collects email during checkout) or complete inline verification cleanly without dead-end website detours.
- **Harden in-app WebViews:** Users clicking paywall links from WhatsApp, Telegram, or social apps land inside restricted mobile WebViews where APIs like `navigator.clipboard.writeText` throw `NotAllowedError`. Always provide a fallback (e.g. `document.execCommand("copy")` + graceful toast) on copy buttons for referral links and setup codes.
- **Isolate multi-product Stripe accounts strictly by metadata:** When one Stripe account serves multiple founder projects, tag Checkout sessions, `subscription_data.metadata`, and `product_data.metadata` with `metadata.product = "<app>"` (using inline `price_data` when restricted keys lack `product_write`), verify raw-body HMAC-SHA256 webhook signatures, and ignore sibling products — then verify live with signed synthetic events for both your product and a sibling product.
- **Roll out monetization softly on existing organic communities:** When turning on billing for a product with grandfathered active groups, never hard-lock thriving communities overnight. Surface non-blocking plan & usage meters (e.g. `X / 50 members`) with 1-click upgrade CTAs in both admin settings and list views, while keeping a clear free path for nonprofits/small groups.

## Paywall Hygiene

- **Silence noise, keep owner clarity:**
  - Never send paywall spam in response to passive emoji reactions, webhook echoes, or background retries.
  - Never expose personal auth tokens in group chats or to non-owner third-party contacts.
  - *Do* deliver a clear, localized paywall message when the owner actively requests work (including when deferred/async background work wakes up over quota).
- **Avoid internal jargon in paywall copy:** Say `"finished its free trial"` or `"out of credits"` with a clear starting price (`from $X/mo`) — never expose internal billing counters or engineering terms.

## Aha-Moment Referral Loops

- **Product unlock > cash affiliate for free users:** When a free user is active and approaching limits, offering an immediate, zero-math reward (e.g., `+1 free week` automatically when a friend sends their first message) consistently outperforms 20% affiliate revshare pitches.
- **Trigger on real value, never Turn 1:** Schedule the referral nudge once per user *after* they demonstrate genuine habit (e.g. `2+` active days and `15+` meaningful runs) — and repeat the referral option calmly as a secondary path inside the paywall message.
- **Make sharing effortless:** Provide a personal, attribution-preserving URL that drops the invited friend straight into a zero-auth product experience and grants the reward automatically upon the friend's first real action.
