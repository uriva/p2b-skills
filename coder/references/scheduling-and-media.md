# Scheduling, Media & Data-Store Anti-Patterns

Push-based scheduling patterns, the multimodal media capabilities you already
have, and why never to use a spreadsheet as a data store. For bot prompt/tool
architecture see `bot-architecture.md`; for tech-stack defaults see
`tech-stack.md`.

---

## WhatsApp Integrations

Before doing any work with WhatsApp integrations (including using Supergreen or the official WhatsApp Cloud API), you MUST learn the `p2b-whatsapp` skill to understand the official vs. unofficial pathways, template requirements, and configuration rules.

---

## Scheduling, Webhooks & Background Tasks

Never design polling-based systems. Deno Deploy charges per request, so polling loops will drain the user's credits fast.

### 1. Avoid Polling (Use Webhooks or Wakeup Timers)
Always seek push-based patterns over pull-based ones:
1. **Webhooks:** Have the external service push events to your Deno Deploy endpoint. This is always the first option to explore.
2. **Streaming / change-notification APIs:** Some services offer long-lived connections or change feeds.
3. **prompt2bot's built-in wakeup timer:** If an agent needs to check back on something later (e.g. "did I get a reply?", "has the deployment finished?"), it can set a timeout in its own prompt. The prompt2bot API lets a bot schedule itself to wake up after N milliseconds via `timeout-wakeup`. This means the agent can say "check again in 10 minutes" without any cron job at all—the platform handles the timer.
   - _Example — agent waiting for an external response:_ Bad: set up a cron that runs every minute to check if a reply arrived. Good: the prompt2bot agent uses its wakeup timer (`timeout-wakeup`) to schedule itself 10 minutes in the future. When it wakes up, it checks for the reply. If not yet received, it sets another timer. Zero cron, zero Deno credits burned—it's all handled by the prompt2bot platform.

### 2. Hard Limits on Cron Frequency
- **Hard rule: cron jobs must never run more frequently than once per hour.** Daily is preferred, hourly is the absolute maximum. A cron that runs every minute or every 5 minutes will burn through Deno Deploy's free tier in days. If you find yourself reaching for a short-interval cron, you are using the wrong pattern—stop and rethink.
- If no alternatives are feasible and you genuinely need frequent polling, **do not implement it**. Instead, notify admins and explain the constraint. Let them decide the architecture.

### 3. Scaling & Architecture Choice (Upstash QStash vs. Deno Cron)
- **Deno Cron:** Use Deno cron **only** for small numbers of system-level background/recurring jobs (e.g. exporting a daily read-only report to Google Sheets). Never use Deno cron for user-generated recurring tasks or high-frequency polling, as it burns unnecessary compute hours on Deno Deploy.
- **Upstash QStash (Recommended):** For scheduling events/scripts at arbitrary timestamps, long-running delayed tasks, or handling a large volume of user-generated scheduled actions, use **Upstash QStash** as your event queue.

#### Why Upstash QStash?
- **How it works:** QStash holds your timer/delay in the cloud entirely over stateless HTTP. You publish a delayed execution payload to QStash, and when the timestamp is reached, QStash fires an HTTP POST request back to your webhook endpoint to execute the task. It requires zero idle compute or open connections on Deno Deploy.
- **How to get API Key:** Sign up at [console.upstash.com](https://console.upstash.com/), go to the **QStash** tab, and copy your `QSTASH_TOKEN` (Current Signing Key) into your project's environment variables (`QSTASH_TOKEN`).
- **Pricing:** An extremely generous free tier of **10,000 scheduled requests per day** ($0, no credit card required). Pay-as-you-go thereafter is just $1.00 per 100,000 requests.
- **How to use (Example):** Schedule an execution at a specific Unix timestamp (in milliseconds) using the `Upstash-Not-Before` header:
  ```typescript
  const qstashToken = Deno.env.get("QSTASH_TOKEN");
  const targetUrl = `https://your-app.deno.dev/w/your-route-id`;

  const response = await fetch(
    `https://qstash.upstash.io/v2/publish/${targetUrl}`,
    {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${qstashToken}`,
        "Content-Type": "application/json",
        "Upstash-Not-Before": String(Math.floor(targetTimestampMs / 1000)),
      },
      body: JSON.stringify(payload),
    },
  );
  ```

### 4. Reminders & User-Facing Scheduling vs. Internal Tools
- **Do NOT use your own `automation/schedule_action` tool** to implement scheduling features in applications you're building. That tool is for YOUR OWN task management—it schedules YOU (the p2b-coder bot) to send messages in your own conversations. It has nothing to do with the applications or bots you're building for users.
- **To schedule target bots to message their users:** When the application you're building needs scheduled or recurring messages (e.g. daily check-ins, reminders), use the prompt2bot `create-remote-task` API with `recurrenceRule`.
- **For inactivity nudges or turn-level timeouts:** Define recurring behavior directly in the target bot's prompt using the `timeout-wakeup` tool. The bot must always be the sender so it maintains full context.

---

## Images, Video, and Media Analysis

prompt2bot agents are **multimodal** — they can see and analyze images and video that users send in chat. When a user sends a photo via WhatsApp (or any other channel), the agent receives it as part of the conversation context and can analyze it directly using its built-in AI model. **No separate Gemini API key, Vision API, or external image analysis service is needed.**

This means: if the product requires analyzing user-sent images (e.g. food photos for a nutrition bot, receipts, documents, screenshots), the prompt2bot agent handles that natively. The agent just needs a prompt that tells it what to extract from images, and it should store the results (e.g. in InstantDB). Don't build a separate image-processing microservice or request AI API keys for this — it's already built in.

The only time you need a separate AI API is for **batch processing of images that don't come from user conversations** (e.g. processing a backlog of images from a storage bucket). For anything sent by users in chat, the agent does it.

### Document Extraction & Parsing Pipelines
When building pipelines to parse and extract structured data from documents (such as insurance policy documents, CRM onboarding forms, or legal files), there are strict precision, cost, and architecture rules to follow:
- **Always load the document-pipeline skill:** For tasks requiring document processing and extraction pipelines, **immediately learn the p2b-document-pipeline skill** to load the complete document-pipeline guidelines and best practices.
- **Image vs. PDF strategy:** Avoid running heavy vision models directly on raw images (JPG/PNG) when extracting precise structured values. Use OCR-first (Google Cloud Vision OCR) to extract text, and run text models on that text instead. For native PDFs with selectable text, avoid OCR completely and convert them directly to text programmatically.
- **Model Selection:** Avoid using the latest Claude directly on raw document images as they can occasionally hallucinate or miss details. Prefer the latest Gemini models for native, high-precision structured data extraction over large multimodal document contexts.

---

## Anti-Pattern: Spreadsheets and Mutable Generic Interfaces as Data Stores

**Never suggest Google Sheets, Airtable, Notion databases, or any spreadsheet-like tool as the backing store for an application.** These tools let users add columns, change types, and rename fields on the fly — every such edit silently breaks the code that reads from them. Production bugs from out-of-sync spreadsheets are extremely common and hard to debug because the schema lives outside the repo, outside CI, outside types.

**Use InstantDB** (or any real database) with the schema defined in `instant.schema.ts` and pushed from CI. The schema is code, lives in git, is reviewed in PRs, and is type-checked.

### What to do when the user asks for spreadsheet-like capabilities:

| User wants | Do this instead |
|---|---|
| "I want to see/edit the data" | Build them an admin dashboard (Next.js + InstantDB + shadcn/ui). Give them proper forms and tables. |
| "I want to add a new column myself" | Push back. Schemas are code. Offer to add the column for them in the repo, or teach them to PR it. |
| "I want non-developers to change the schema" | Push back harder. This is how data corruption and broken code happens. The schema is a contract between the database and all code that reads it. |
| "Our ops team lives in Sheets" | Export a read-only Sheet from your InstantDB via a scheduled job if they need to view data. Writes still go through the dashboard. |

**If the user insists on a spreadsheet-backed system, explain the tradeoff clearly and object.** "I can build this with Google Sheets, but every time someone changes a column name or type, the bot breaks silently and no one will know until a user complains. Schemas are a contract — they belong in code, managed by a developer (human or p2b-coder), not in a document anyone can edit."

This also rules out:
- Using a spreadsheet as a task queue
- Using a spreadsheet as the config for a bot
- Using a Notion database to drive application behavior
- Any "low-code admin interface" where end users change the data model

Edit capabilities belong in **dashboards you build**. Schema changes belong in **code reviewed by a developer**. Never conflate the two.
