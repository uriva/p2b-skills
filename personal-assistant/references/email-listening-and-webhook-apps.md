# Email & Message Listening via Mini Webhook Apps

This guide explains how personal assistant bots track incoming emails or
messages and proactively help their owners answer them using **mini
webhook-driven apps** powered by Safescript.

---

## Architecture Overview (Internal — Do Not Dump Details on the User)

Instead of spinning up external infrastructure or polling inboxes repeatedly, a
Prompt2Bot agent creates a **mini webhook app** listener directly on the bot.

**Important User-Facing Rule:**
- When the owner asks if you can listen to their emails ("my emails"), they mean
  **their own inbox** (e.g. Gmail). Never mention `AgentMail` or an email
  address for the assistant (`@theagentmail.net`) — that has nothing to do with
  listening to the owner's emails.
- Do not lecture the owner about internal implementation details (`Webhook App`,
  `Safescript`, `decisionModel` / "decision model", `notifyMe`, `Composio`, or
  burning agent runs), and do not ask them to pick between "periodic polling /
  direct Gmail connection" and a "Webhook App". The webhook app listener is the
  single right path; keep all plumbing details under the hood and speak to the
  owner in plain, outcome-focused language.

1. **Webhook Endpoint:** Each app gets an edge webhook URL:
   `https://api.prompt2bot.com/webhook-app/<botId>/<appName>`.
2. **Event Trigger:** Incoming email events from the owner's email integration
   (such as Gmail push/forwarding, Resend, or SendGrid) POST incoming email data
   to this endpoint.
3. **Edge Safescript Execution:** The incoming payload is executed in Safescript
   using two core primitives:
   - `decisionModel`: Intelligently classifies the email (urgency, importance,
     action required) using an AI decision model.
   - `notifyMe`: Alerts the agent via the creator thread by system notification.
4. **Proactive Owner Loop:** The assistant receives the system notification in
   the creator thread and reaches out to the owner with a summary and a draft
   reply. When the owner responds on WhatsApp (e.g. "Yes, send it" or "Tell them
   next week"), the assistant executes the reply.

---

## The Two Primitives

### 1. `decisionModel`

Evaluates whether a message/email requires attention.

```safescript
isUrgent = decisionModel({
  question: "Is this email urgent, important, or does it require an answer from the owner?",
  context: { sender: sender, subject: subject, body: body }
})
```

- **Syntax:** Can be called with an object (`{ question, context, threshold? }`)
  or unary string (`decisionModel("Is this email urgent?")`).
- **Return Value:** Returns a boolean (`true` or `false`).
- **Cost & Billing:** Decision model runs are billed at a fraction of an agent
  run rather than a full turn. Check the platform's
  `decisionModelAgentRunMultiplier` in `constants.ts` or the dashboard settings
  for the exact multiplier ratio. This allows listening to tens of thousands of
  incoming emails, newsletters, and receipts each month without exhausting
  monthly agent run quotas.

### 2. `notifyMe`

Alerts the agent via the creator thread by system notification.

```safescript
notifyMe({
  subject: "Important email from " + sender,
  message: "New message from " + sender + ": " + subject + "\n\n" + snippet
})
```

- **Syntax:** Object (`{ message, subject?, network? }`) or unary string
  (`notifyMe("Alert message")`).
- **Effect:** Enqueues a system notification (`inject-context`) into the
  creator's thread. The assistant in that thread wakes up to the system
  notification, summarizes the context to the owner, and proactively asks how to
  handle it.

---

## Step-by-Step: Setting Up Email Listening

### Step 1: Create the Webhook App

Use the `create_webhook_app` tool to deploy the listening logic:

```safescript
main = (payload) => {
  sender = payload.from == null ? "Unknown" : payload.from
  subject = payload.subject == null ? "No subject" : payload.subject
  text = payload.text == null ? "" : payload.text

  isImportant = decisionModel({
    question: "Does this email require an answer, decision, or timely action from the recipient?",
    context: { sender: sender, subject: subject, text: text }
  })

  if (isImportant) {
    notifyMe({
      subject: "Urgent: " + subject,
      message: "From: " + sender + "\nSubject: " + subject + "\n\n" + text
    })
  }

  return { success: true, processed: isImportant }
}
```

The tool returns the webhook URL:
`https://api.prompt2bot.com/webhook-app/<botId>/email-listener`

### Step 2: Connect Incoming Email Trigger

Connect the owner's email source to trigger the webhook URL:

- **Gmail:** Use Gmail push notifications or forwarding to trigger the webhook.
- **Resend / ForwardEmail / SendGrid:** Add the URL as the inbound webhook
  target.

### Step 3: Proactive Answering on WhatsApp

When an urgent email arrives:

1. The mini app's `decisionModel` detects it requires action and calls
   `notifyMe`.
2. The assistant sends a proactive message to the owner on WhatsApp:
   > _"Hey! You received an email from Alex (alex@acme.com) regarding 'Q3
   > Contract Renewal'. Summary: They want to know if we can sign by Thursday.
   > Would you like me to reply that Thursday works and request the finalized
   > agreement?"_
3. The owner simply answers on WhatsApp:
   > _"Yes, send that"_
4. The assistant sends the email using `p2b-gmail` (`sendGmailEmail`) or
   connected email tools, and confirms delivery on WhatsApp.
