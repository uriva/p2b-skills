---
name: p2b-whatsapp
description: WhatsApp integration skill for prompt2bot agents. Covers official vs unofficial integration paths, simple notifications vs full interactive agent experiences, and API constraints.
---

# p2b-whatsapp

WhatsApp integration skill for prompt2bot agents. Covers when to use official vs unofficial lines, simple push messages vs back-and-forth agent interactions, and programmatic API implementation with associated constraints.

---

## Integration Pathways & Interaction Types

When building for WhatsApp, there are two axes to consider: **Integration Pathway** (Official vs. Unofficial) and **Interaction Type** (Simple Notification vs. Agent Experience).

| Integration Pathway | Simple Messaging (One-Way Notification) | Agent Experience (Interactive Conversational Bot) |
| :--- | :--- | :--- |
| **Official (Meta Business API / Cloud API)** | Send transactional messages programmatically. **Strictly limited to pre-approved templates** outside a 24-hour window. | Back-and-forth AI conversations. Requires the WhatsApp for Business Token (`whatsappForBusinessToken`) configured in InstantDB. |
| **Unofficial (Supergreen)** | Direct outbound API pings via Supergreen. Free-form text and attachments, skipping Meta's approval process and template restrictions. | Connect a Supergreen WhatsApp line to the prompt2bot agent via `setSupergreenWhatsapp` or the dashboard. |

---

## 1. Simple Messaging (One-Way Notifications)

Use this when you only need to trigger outbound alerts, receipts, or reminders without any interactive conversation.

### Unofficial (Supergreen Direct)
For quick, template-free alerts, query the Supergreen HTTP API directly.
```typescript
await fetch("https://api.supergreen.cc/message", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "Authorization": `Bearer ${Deno.env.get("SUPERGREEN_API_KEY")}`,
  },
  body: JSON.stringify({
    to: "972501234567",
    text: "Your order has been shipped! Track it here: https://example.com/track",
  }),
});
```

### Official (Meta / prompt2bot API)
Use the `@prompt2bot/client` API to schedule the notification.
- **CRITICAL Official WhatsApp Constraint (Templates):** If using the official integration, outbound messages sent outside the 24-hour interactive window **must** utilize pre-approved WhatsApp templates inside your Meta Business Manager. Free-form text will fail.
- You must format template parameters using `whatsappTemplateName`, `whatsappTemplateLanguage`, and `whatsappTemplateVariables`.
- New templates cannot be created programmatically; they must be pre-approved in Meta Business Manager.

---

## 2. Agent Experience (Interactive Conversations)

Use this when you want a smart, back-and-forth conversational AI with access to tools, knowledge bases, and persistent context.

### Setup and Integration
1. **Official**: Bot must have its WhatsApp for Business Token (`whatsappForBusinessToken`) stored and configured in InstantDB.
2. **Unofficial**: Link your Supergreen line to the prompt2bot instance via the `@prompt2bot/client` SDK or the dashboard:
   ```typescript
   import { setSupergreenWhatsapp } from "@prompt2bot/client";
   
   // Links the Supergreen connection to the bot
   await setSupergreenWhatsapp({
     secret: Deno.env.get("PROMPT2BOT_SECRET"),
     supergreenApiKey: Deno.env.get("SUPERGREEN_API_KEY"),
   });
   ```

### Triggering Proactive Agent Tasks (`createRemoteTask`)
Instead of simple, static pings, you can schedule an agent to proactively initiate an interactive conversation using the `@prompt2bot/client` library. The bot receives the `description` as an internal prompt, boots its VM, constructs a context-aware message, and contacts the user on WhatsApp.

```typescript
import { createRemoteTask } from "@prompt2bot/client";

// Schedule the agent to proactively investigate and contact a user
await createRemoteTask({
  secret: Deno.env.get("PROMPT2BOT_SECRET"),
  description: "CI pipeline failed on main. Analyze logs, trace the failure, and offer to open a fix PR.",
  preferredNetwork: "whatsapp",
  contactWhatsAppNumber: "972501234567",
  runAt: Date.now(),
});
```

To schedule recurring conversations, pass a `recurrenceRule` (supports `"daily"`, `"weekly"`, `"monthly"`, milliseconds, or an RFC 5545 RRULE string):
```typescript
await createRemoteTask({
  secret: Deno.env.get("PROMPT2BOT_SECRET"),
  description: "Run the full test suite, scan for flaky tests, and check in on how they look.",
  preferredNetwork: "whatsapp",
  contactWhatsAppNumber: "972501234567",
  recurrenceRule: "daily",
});
```

---

## 3. Best Practices & Webhook Hygiene

- **Verify Tokens Programmatically:** Before attempting to test or invoke any message flow, programmatically verify that the target bot has either `whatsappForBusinessToken` (for official lines) or an active Supergreen configuration. Proactively report missing tokens to users rather than letting calls fail silently.
- **Never Lie About Failures:** If a webhook, test message, or scheduled task fails, do not invent system myths (e.g., claiming a phone line is "sleeping" or in a "cold state"). Check the logs, check InstantDB task states, and communicate transparently.
- **Avoid Polling Loops:** Do not set up high-frequency cron jobs or polling loops (polling more than once per hour is strictly forbidden on Deno Deploy). Instead:
  1. Use push-based **Webhooks**.
  2. Use the prompt2bot native **Wakeup Timer** (`timeout-wakeup`) to let the bot wake itself up after a duration.
  3. Use **Upstash QStash** to queue delayed callbacks statelessly via HTTP triggers.
