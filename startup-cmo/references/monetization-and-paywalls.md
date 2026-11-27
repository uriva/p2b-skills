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

## Zero-Friction Paywall & Checkout UX

- **Authenticated 1-tap upgrade links:** Every paywall message delivered in chat, email, or in-app should link directly to `/pricing?token=<one-time-auth-token>` so the user lands already signed in and can reach Stripe/billing checkout in one click.
- **Guard auth-in-flight states:** On `/pricing?token=...`, never let an unauthenticated render flash a "Sign in to upgrade" wall or redirect to `/login` before the token exchange finishes.
- **Support channel-native checkout:** If a user signed up via WhatsApp/Telegram/phone without linking an email address, allow Stripe Checkout without requiring a pre-linked email (Stripe collects email during checkout). Never block a ready buyer with an unnecessary "please add an email in settings first" detour.
- **Harden in-app WebViews:** Users clicking paywall links from WhatsApp, Telegram, or social apps land inside restricted mobile WebViews where APIs like `navigator.clipboard.writeText` throw `NotAllowedError`. Always provide a fallback (e.g. `document.execCommand("copy")` + graceful toast) on copy buttons for referral links and setup codes.

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
