# Bot Architecture: Prompts, Tools & the prompt2bot API

How to structure the bots you build — put behavior in prompts, use the
prompt2bot API to configure them, and never wrap the agent in an external state
machine. For scheduling/webhooks see `scheduling-and-media.md`; for CI wiring see
`planning-and-design.md`.

---

## Agent Behavior Belongs in Prompts, Not Code

When building a bot, don't implement its behavioral logic as an external state machine or server-side workflow. Instead, give the agent tools and guidelines in its system prompt, and let it decide when to use them. This is more robust — the agent handles edge cases, adapts to context, and recovers from unexpected states naturally, while a hardcoded state machine breaks on any path you didn't anticipate.

**Example — follow-up nudges:** If a bot needs to nudge users who stop responding during onboarding, don't build an external cron job or call the `create_remote_task` API. Instead, write in the bot's prompt: "Whenever you ask a question during onboarding, call `timeout-wakeup(ms: 300000)`. If the timeout triggers, nudge the user with [Specific Message]." The framework cancels the timeout automatically if the user replies early.

**Never send messages that bypass the bot.** If a bot manages conversations with users (via prompt2bot/WhatsApp/Telegram/etc.), every outbound message must go through the bot — never send messages directly via Supergreen, WhatsApp API, or any other channel behind the bot's back. If you do, the bot's conversation history won't contain those messages, and when the user replies, the bot has no idea what they're responding to. For scheduled/recurring messages (daily check-ins, reminders, etc.), use `create-remote-task` to have the bot send them. For agent-initiated nudges on inactivity, use `timeout-wakeup` in the bot's prompt. The bot must always be the sender so it maintains full context.

**Do NOT use your own `automation/schedule_action` tool to implement scheduling features in applications you're building.** That tool is for YOUR OWN task management — it schedules YOU (the p2b-coder bot) to send messages in your own conversations. It has nothing to do with the applications or bots you're building for users. When the application you're building needs scheduled or recurring messages (e.g. daily check-ins, reminders), use the prompt2bot `create-remote-task` API with `recurrenceRule` to schedule the **target bot** to message its users. Or define recurring behavior in the target bot's prompt with `timeout-wakeup`. Never confuse your own internal tools with application-level functionality you should be coding or configuring via APIs.

**General principle:** Your job as the developer is to write prompts that give agents autonomy via their existing tools, not to build external services that manage agent state.

---

## Writing Prompts and Injecting Thoughts

When writing prompts for prompt2bot agents or injecting thoughts via the `inject-context` API, focus purely on defining clear instructions, scenario details, and business behavior.

- **Avoid prompt workarounds for platform bugs:** Never add defensive instructions, lists of behaviors to avoid, or negative guardrails (especially using words like "CRITICAL", "WARNING", "never do X") to cover up bugs elsewhere in the system, particularly bugs in prompt2bot itself (e.g., leaking thoughts or other agent misbehaviors). The prompt or thought injection should be concise, direct, and just work.
- **Identify systemic or tooling misfits:** If an agent misbehaves or leaks thoughts, it means there is either a platform bug that needs to be reported, or the tooling itself confuses the agent or does not fit the scenario. Report the bug or fix the tools, instead of cluttering agent prompts with defensive rules.

---

## Per-User / Per-Conversation Prompt Variation: `remote_config`

`setPrompt` sets one prompt for the whole bot. When the prompt needs to vary per user or per conversation (e.g. multi-tenant bots, user-specific knowledge, A/B tests), use the **`remote_config`** tool hook instead of calling `setPrompt` at runtime.

If you register a custom tool named `remote_config` via `setCustomTools`, the prompt2bot server calls it on **every incoming message**. It's not exposed as a callable tool to the agent — it's a config fetcher. Your endpoint receives the usual signed request (including `meta.conversationId`, `meta.userId`, `meta.botId`) and returns JSON with optional fields:
```json
{ "prompt": "...", "timezoneIANA": "Europe/Berlin" }
```

The returned `prompt` **replaces** the bot's static prompt for that turn. If the fetch fails or returns nothing, the server falls back to the bot's stored prompt. Leave `params` empty for this tool — it gets called with `{}`.

This inverts the control flow correctly: the backend server (which already holds user data) decides what prompt each conversation should get, and the bot never needs to mutate its own configuration. Combine with `setPrompt` from CI to set the **default** prompt and use `remote_config` for overrides.

**When to use which:**

| Situation | Mechanism |
|---|---|
| One prompt for the whole bot | `setPrompt` from CI |
| Different prompt per user / per conversation | `remote_config` tool |
| Different timezone per conversation | `remote_config` tool (`timezoneIANA`) |
| Different tool set per user | Conditional logic inside each tool |

Do NOT call `setPrompt` on every message to fake per-conversation prompts — it's global state and races badly.

---

## Using the prompt2bot API (`@prompt2bot/client`)

The `@prompt2bot/client` library (JSR: `jsr:@prompt2bot/client`) lets you programmatically manage bots, send messages, register tools, and update prompts. **Never ask users to manually configure things in the dashboard** — use the API instead.

### Authentication model — two different tokens:
- **General API token (`p2b_` prefix)** — tied to a user account. Used for account-level operations: `createBotApi` (creating new bots), `loginWithToken`, and **listing bots**. You rarely need this unless you're creating bots programmatically or need to discover bot IDs.
- **Bot Remote Tools Secret** — tied to a specific bot. Used for everything else: `setCustomTools`, `setPrompt`, `createRemoteTask`, `injectContext`, `setSupergreenWhatsapp`. This is the secret stored via `set_secret` on the VM. **This is the token you use for 99% of API calls.**

**If you need a bot ID**, ask the user — it's visible in the dashboard URL (e.g. `https://prompt2bot.com/bots/<bot-id>/...`). Don't ask the user for the general API token just to list bots when they can read the ID from the URL.

When you need to call the prompt2bot API from the VM, store the bot's Remote Tools Secret using `set_secret` (e.g. as `PROMPT2BOT_SECRET`), then use it directly:
```js
// Send a proactive WhatsApp message to a user
fetch("https://api.prompt2bot.com/api", {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({
    endpoint: "create-remote-task",
    payload: {
      secret: Deno.env.get("PROMPT2BOT_SECRET"),
      description: "Tell the user their report is ready and share the link.",
      preferredNetwork: "whatsapp",
      contactWhatsAppNumber: "972501234567",
      runAt: Date.now(),
    },
  }),
});
```

### Key API endpoints (all use the bot's Remote Tools Secret):
- **`createRemoteTask`** — Schedule the bot to proactively message a user. Use for reminders, notifications, follow-ups. The `description` is an internal thought the bot acts on — it will compose the actual message. (Note: For WhatsApp-specific template and integration constraints, learn the `p2b-whatsapp` skill).
- **`injectContext`** — Push context into an active conversation immediately (no queue). Use for real-time reactions to webhooks or delivering deferred tool results.
- **`setCustomTools`** — Register HTTP tool endpoints on the bot programmatically. Never ask users to add tools in the dashboard. A tool named `remote_config` is special — see "Per-user prompt variation" above.
- **`setPrompt`** — Set the bot's default system prompt. Call this from CI on every push to `main` so the prompt is always in sync with the repo. For per-conversation variation, use `remote_config` instead — do NOT call `setPrompt` per message.

**When creating bots via `create-bot-api`, always pass `checkForHallucinations: true`.** This enables automatic hallucination detection — every bot response is verified by a secondary AI model for factual accuracy. If a hallucination is detected, the bot self-corrects before the user sees the bad response. There is no reason to leave this off.

---

## Anti-Pattern: Building a State Machine Around the Agent

**Never use webhooks, chat recording hooks, or external code to manage conversation flow or track conversation state.** The prompt2bot agent IS the conversation manager — its prompt defines behavior, its tools provide capabilities, and its memory maintains state across messages. Building a state machine or response tracker on top of a webhook that records the conversation nullifies the agent's mind. The agent can no longer reason about the conversation because decisions are being made externally.

If the user needs a bot that follows a multi-step flow (e.g. onboarding, intake form, support ticket), implement it as:
- A **prompt** that describes the flow and decision points
- **Tools** the agent can call to read/write data (e.g. InstantDB queries)
- The agent's own **conversation history** to track where the user is in the flow

Never build: a webhook endpoint that receives each message, looks up state in a database, decides what to reply, and sends the reply back. That's reimplementing the agent from scratch and throwing away everything prompt2bot gives you.

---

## Architecture Patterns

**Agent frontend + pipeline backend:** Many systems combine a data pipeline / scraping / recurring tasks (on Deno) with an agent that helps the user interact with the system (on prompt2bot). Use the prompt2bot API to create an agent, get a secret token, and inject context or activate it from the backend based on schedules or events.

**Simple frontend / forms:** Use Next.js (App Router) on Deno Deploy.
