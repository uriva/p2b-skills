---
name: p2b-stripe
description: Stripe subscription and payment billing integration for prompt2bot agents — tool design, Stripe checkout links, dynamic customer portal sessions, webhooks, and secure sandbox routing.
---

# p2b-stripe

Stripe subscription and payment billing integration skill for prompt2bot agents.
Covers tool design, checkout generation, dynamic portal session handling,
webhook validation, and database updates.

## Instructions

### 1. Structure of Agent Billing Tools

To enable agents to process payments natively during conversation, the bot must
expose a dedicated `billing` skill with two primary tools:

#### A. Checkout Link Generation (`generate_stripe_checkout_link`)

- **Purpose**: Generates a Stripe Checkout URL for users to purchase or upgrade
  to a premium/Pro tier.
- **Dynamic Tier & Price ID Selection**:
  - The tool should accept an optional `tier` or `priceId` parameter. This
    allows the bot to dynamically generate checkout sessions matching the
    specific tier desired by the user (e.g. `"50_credits"`, `"150_credits"`, or
    `"500_credits"`).
- **Stripe API Key Permissions (`sk_` vs `rk_`)**:
  - To dynamically generate checkout sessions, Stripe's API requires an API key
    with **"Checkout Sessions Write" (`checkout_session_write`)** and **"Prices
    Read" (`plan_read`)** permissions.
  - If the configured key is a **Restricted API Key** (`rk_live_...`) lacking
    these permissions, Stripe will return a `Permission Denied` error.
- **Implementation & Fallback**:
  - Call the Stripe SDK `checkout.sessions.create` API with the selected
    `priceId` and the user's `customer_email`.
  - If the secret override `STRIPE_PRO_LINK` is set, return it immediately.
  - **Graceful Fallback**: If the API key lacks permissions or is missing, catch
    the error and fall back gracefully to a static Stripe Payment Link
    (`https://buy.stripe.com/...` URL) so the user is never blocked.

```typescript
// Dynamic Checkout Session Generation with Fallback
export const generateCheckoutSessionLink = async (
  priceId: string,
  email: string | null | undefined,
): Promise<string> => {
  const apiKey = await getSecret("STRIPE_SECRET_KEY")
    .catch(() => getSecret("STRIPE_API_KEY"))
    .catch(() => "");
  if (!apiKey) {
    throw new Error("STRIPE_SECRET_KEY is missing.");
  }
  const stripeClient = new Stripe(apiKey);
  const session = await stripeClient.checkout.sessions.create({
    mode: "subscription",
    payment_method_types: ["card", "link"],
    line_items: [{ price: priceId, quantity: 1 }],
    ...(email && { customer_email: email }),
    success_url: "https://your-app.com/settings?checkout=success",
    cancel_url: "https://your-app.com/pricing?checkout=cancelled",
  });
  return session.url!;
};

// Example Tool Handler
defineTool({
  name: "generate_stripe_checkout_link",
  description:
    "Generate a Stripe checkout link. Optional 'tier' parameter allows selecting custom tiers.",
  parameters: z.object({
    tier: z.enum(["tier_1", "tier_2", "tier_3"]).optional(),
  }),
  handler: async ({ tier }) => {
    const defaultPriceId = "price_YOUR_PRICE_ID_1";
    const priceIdMap = {
      "tier_1": "price_YOUR_PRICE_ID_1",
      "tier_2": "price_YOUR_PRICE_ID_2",
      "tier_3": "price_YOUR_PRICE_ID_3",
    };
    const priceId = priceIdMap[tier || "tier_1"] || defaultPriceId;
    const defaultFallback = "https://buy.stripe.com/YOUR_DEFAULT_PAYMENT_LINK";
    try {
      const link = await getSecret("STRIPE_PRO_LINK").catch(() => "") ||
        await generateCheckoutSessionLink(
          priceId,
          await resolveEmail(userId()),
        );
      return { url: link };
    } catch (error) {
      console.error(
        "Failed to generate dynamic Stripe checkout session:",
        error,
      );
      return { url: defaultFallback };
    }
  },
});
```

#### B. Customer Portal Link Generation (`generate_stripe_portal_link`)

- **Purpose**: Generates a Stripe Customer Portal link so users can securely
  cancel, update, or manage their subscriptions.
- **CRITICAL IMPLEMENTATION DETAIL**:
  - Never return a static, hardcoded hosted login portal URL like
    `https://billing.stripe.com/p/login/YOUR_PORTAL_SLUG`. These links return
    **HTTP 404** unless the customer portal login page has been explicitly
    activated in the Stripe Dashboard.
  - **Dynamic Portal Session Generation**: Instead, dynamically create a
    pre-authenticated, short-lived portal session using the Stripe SDK.
  - **The Lookup Flow**:
    1. Resolve the current user's email address from their conversation state.
    2. Check the database for a stored `stripeCustomerId`. If not found, call
       Stripe's Customer List API (`stripe.customers.list({ email, limit: 1 })`)
       to find the matching Customer ID by email dynamically.
    3. Call the Stripe Billing Portal API
       (`stripe.billingPortal.sessions.create({ customer: customerId, return_url })`)
       to generate the portal session URL.
    4. Fall back to the configured default hosted login portal ONLY if
       `STRIPE_SECRET_KEY` is missing or the dynamic creation fails.

```typescript
// Dynamic Portal Session Generation Code
import Stripe from "stripe";

export const generateCustomerPortalLink = async (
  email: string,
): Promise<string> => {
  const defaultFallback = "https://billing.stripe.com/p/login/YOUR_PORTAL_SLUG";
  try {
    const apiKey = await getSecret("STRIPE_SECRET_KEY")
      .catch(() => getSecret("STRIPE_API_KEY"))
      .catch(() => "");
    if (!apiKey) return defaultFallback;

    const stripeClient = new Stripe(apiKey);
    const customers = await stripeClient.customers.list({ email, limit: 1 });
    if (!customers.data || customers.data.length === 0) return defaultFallback;

    const customerId = customers.data[0].id;
    const session = await stripeClient.billingPortal.sessions.create({
      customer: customerId,
      return_url: "https://your-app.com",
    });
    return session.url;
  } catch (error) {
    console.error("Failed to generate dynamic customer portal link:", error);
    return defaultFallback;
  }
};
```

---

### 2. Webhook Subscription & Verification

To securely handle payment events from Stripe (such as initial checkouts and
monthly recurring renewals), you must configure a secure `/stripe` webhook
endpoint that receives `POST` requests directly from Stripe.

#### Webhook Signature Verification

To prevent spoofing, every webhook payload must be cryptographically verified
using the `stripe-signature` header and your configured `STRIPE_WEBHOOK_SECRET`.

- The `stripe-signature` header contains a timestamp (`t=...`) and one or more
  signatures (`v1=...`).
- You must compute a SHA256 HMAC of the payload concatened with the timestamp,
  using the webhook secret, and compare it with the signature.

```typescript
import { createHmac } from "node:crypto";

export const verifyStripeWebhook = (
  rawBody: string,
  signatureHeader: string,
  webhookSecret: string,
): boolean => {
  try {
    const parts = signatureHeader.split(",");
    const tPart = parts.find((p) => p.startsWith("t="));
    const v1Part = parts.find((p) => p.startsWith("v1="));
    if (!tPart || !v1Part) return false;

    const timestamp = tPart.substring(2);
    const signature = v1Part.substring(3);

    const signedPayload = `${timestamp}.${rawBody}`;
    const expectedSignature = createHmac("sha256", webhookSecret)
      .update(signedPayload)
      .digest("hex");

    return expectedSignature === signature;
  } catch {
    return false;
  }
};
```

---

### 3. Handling Webhook Events

You must listen for the following two core webhook events to handle user
subscriptions and recurring renewals:

#### A. `checkout.session.completed`

Fired when a user successfully completes a Stripe Checkout session. This event
is responsible for provisioning the initial Pro tier access and sending a
welcome email.

#### B. `invoice.payment_succeeded`

Fired every time a recurring monthly subscription invoice is successfully paid.
This event is responsible for maintaining the user's Pro status or adding search
credits.

#### Processing Pipeline:

1. Read the event `type` and the `data.object`.
2. Extract the customer's email from `customer_details.email` or
   `customer_email`.
3. Verify that the purchased items contain one of your allowed `price_` IDs. If
   the checkout contains line items, use
   `stripe.checkout.sessions.lineItems.list(sessionId)` to fetch and verify the
   price IDs.
4. Record the payment event in the database (e.g. adding a new entry to the
   `paymentEvents` table with `amountUSD`, `type: "stripe"`, and `timestamp`).
5. Provision/upgrade the user's tier or credits, and send a welcome email.

```typescript
// Stripe Webhook Event Processor Example
export const stripeHandler = async (payload: StripeEvent) => {
  const eventType = payload.type;
  const dataObject = payload.data?.object;
  if (!dataObject) return;

  let email = dataObject.customer_details?.email || dataObject.customer_email;
  let amountCents = dataObject.amount_total || dataObject.amount_paid || 0;
  if (!email) return;

  const allowedPriceIds = [
    "price_YOUR_PRICE_ID_1",
    "price_YOUR_PRICE_ID_2",
    "price_YOUR_PRICE_ID_3",
  ];
  let hasMatchingPrice = false;

  if (eventType === "invoice.payment_succeeded") {
    const invoiceLines = dataObject.lines?.data || [];
    hasMatchingPrice = invoiceLines.some((line) =>
      allowedPriceIds.includes(line.price?.id)
    );
  } else if (eventType === "checkout.session.completed") {
    const stripeApiKey = await getSecret("STRIPE_SECRET_KEY").catch(() => "");
    if (stripeApiKey) {
      const lineItems = await fetchCheckoutSessionLineItems(
        dataObject.id,
        stripeApiKey,
      );
      if (lineItems) {
        hasMatchingPrice = lineItems.some((line) =>
          allowedPriceIds.includes(line.price?.id)
        );
      }
    }
  }

  if (!hasMatchingPrice) return;

  // Add payment event to database
  await addPaymentEvent(email, "stripe", amountCents / 100);

  if (eventType === "checkout.session.completed") {
    await sendWelcomeToProEmail(email);
  }
};
```

---

### 4. Security & Sandbox Routing Best Practices

When running Stripe billing integrations inside AI-agent-built apps, strictly
adhere to these security mandates:

- **Universal Secrets Configuration**: Always configure Stripe secrets in
  **Infisical** or as secure environment variables. Never commit raw Stripe keys
  (`sk_live_...` or `sk_test_...`) to the codebase.
- **Allowed Hosts Filtering**: Ensure that the Stripe webhook verification
  endpoint and client API calls only accept connections originating from the
  official Stripe IP ranges and domain names (`api.stripe.com`,
  `checkout.stripe.com`, `billing.stripe.com`).
- **Allowed Hosts Proxy**: In sandboxed programming environments (like
  Safescript), tag all Stripe secrets as **Stripe-only** (restricting outbound
  network egress to the `api.stripe.com` host) to eliminate supply chain attack
  vectors and prevent token exfiltration.
