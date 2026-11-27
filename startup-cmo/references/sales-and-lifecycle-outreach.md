# Founder-Led Sales & Lifecycle Outreach

## Read Real Conversations Before Theorizing

Dashboards show *where* users drop; transcripts show *why*. Whenever a stage underperforms:

- Pull the last 5-15 real conversations, support tickets, or onboarding sessions from users who stalled or hit the paywall.
- Look for exact friction moments:
  - Confusion on Turn 1 ("what can you actually do?") or bare/vague inputs where the bot replies with an open-ended text question instead of **3 clickable 1-tap `<button>` starter options** — open-ended clarification walls cause immediate drop-offs.
  - False-positive safety or "therapist mode" refusals on benign domain inputs (e.g., dramatic movie quotes, creative writing prompts, or domain jargon) that silently kill activation with zero tool calls.
  - Unexpected errors, auth detours, or broken mobile buttons.
  - Sticker shock, premature cap hits ("It ran out already?!"), or walls of text burying a checkout link when users explicitly ask to upgrade.
  - Checkout abandonment (`?checkout=cancelled`) followed by returning to compare options.
- Fix the underlying product, prompt, or UX cause before rewriting ad/landing copy.

## Event-Driven Lifecycle Outreach

Lifecycle messages should feel like a helpful note from a thoughtful founder, never an automated drip campaign:

- **Signed up, never activated:** One short message 24h later with 2 concrete things they can try in 10 seconds (direct link back into the product).
- **Activated, hit paywall, didn't upgrade:** Ensure they received a clear, localized message with both the 1-tap authenticated upgrade link and the free-unlock referral option — never double-ping.
- **Checkout abandoned:** If a user reached Stripe Checkout and cancelled, note the friction (price, missing payment method, or still evaluating). Many buyers convert hours later once they hit the need again — avoid aggressive countdown pressure.
- **Happy power user / high NPS:** Great moment to invite a quick reply ("what's the one thing you'd miss most if this disappeared?") or share their personal referral link.
- **Strict hygiene:** Always deduplicate outreach per user and event, honor opt-outs immediately, and keep every message concise and human.

## Closing the Loop on Every Paid Conversion

When a user converts to a paid plan (especially in early-stage SaaS where every customer teaches you something):

1. Reconstruct their full timeline from first touch to payment:
   - Acquisition source & landing page (`ref`, `utm`, organic vs. social vs. referral).
   - Time to activation and active days before upgrading.
   - Core use case / workflow that created real pull.
   - Any friction along the way (paywall hits, cancelled checkouts, referral checks, NPS score).
2. Share a 5-line breakdown with the founder highlighting **what actually drove the sale** and which acquisition channel or product habit to double down on.

## Founder-Led Sales Posture

- **Diagnose first, pitch second:** Ask what workflow is currently painful or manual, show the exact fit (or honestly tell them when the product isn't a fit).
- **Remove setup friction live:** Non-technical buyers churn on OAuth, DNS, API keys, and channel pairing. Guide them one step at a time or automate the setup wherever possible.
- **Price & scope clarity:** State starting price, what's included, and any add-ons transparently upfront — hidden limits discovered after signup erode trust faster than clear pricing on the page.
