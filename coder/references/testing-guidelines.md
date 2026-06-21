# Testing and Quality Assurance Guidelines

To ensure high-quality, verified software delivery, you must adhere strictly to these testing and verification rules.

---

## Localized & End-to-End (E2E) Testing Instructions (MANDATORY)

- **NEVER SAY SOMETHING IS WORKING OR DONE without BOTH a localized test and an end-to-end (E2E) test by the user.** You are strictly forbidden from declaring a task successful or saying a feature is fully working based only on a build passing or a theoretical fix.
- **Localized/Unit Testing:** Always write and run localized unit or integration tests (e.g., `deno test`, `npm test`) for any sub-parts, handlers, or backend units that you can execute in your environment.
- **Handling Untestable Sub-parts:** Sometimes, you can only test specific sub-parts because you do not have direct access to third-party endpoints, specialized user-facing environments, or user accounts. In such cases:
  1. You must thoroughly test what you can locally (localized test).
  2. You **MUST** instruct the user to fulfill a specific, clear, step-by-step test that you will describe in detail (e.g., "To test this, please open the WhatsApp chat, send the message 'hello', and verify that you receive response X within 10 seconds").
  3. Wait for the user to execute the test and confirm the results before declaring the feature or bug fixed.

---

## Break Work Into Smallest Possible Tasks with User-Verifiable Acceptance Criteria

- **Break work into the smallest possible tasks, each with user-verifiable acceptance criteria.** Every task must end with something a non-technical user can check: "go to this URL and you should see X", "send a message to this number and you should get Y back", "open the dashboard and confirm Z appears". Never use technical checks as acceptance criteria (logs, API responses, deploy status) — the user can't verify those.
- After completing each task, stop and confirm with the user that the acceptance criteria passed before moving to the next task.
- **Never say "I'm done" before the acceptance criteria have been checked.** If you can verify it yourself (e.g. open a URL, send a test message), do that first — but still confirm with the user.
- Before telling the user something is ready, verify it works yourself first. Open the URL in your browser, test the endpoint, check the logs. Never send the user to check something you haven't confirmed is working.
- Never tell the user something is "created", "live", "ready", "fixed", or "done" until the exact acceptance check has passed. Report verified facts only. If a step succeeded but the overall feature still fails, say exactly that — don't imply the whole task is complete.
- If you told the user something will be ready by a certain time, schedule a task or set a timeout to check on it yourself before that time. Don't rely on the user to follow up — you own the deadline.

---

## Testing Remote Tools in Agentic Flows

When building or integrating backend services, APIs, and custom tools for an agent, you should perform true end-to-end integration testing by programmatically starting a conversation with the target agent via **Alice & Bot**. This allows you to simulate a real user interaction, test the conversation flow, and verify that the database is fed correctly and all remote tools/webhooks execute successfully.

### Guidelines for agentic flow testing:
- **Avoid harmful side-effects:** When running end-to-end tests, take extreme care to avoid triggering harmful or irreversible side-effects in production (e.g., sending real marketing spam, charging real credit cards, or deleting production databases). Always use mock data, dedicated test users, or safe test modes where appropriate.
- **Obtaining the Alice & Bot Public ID:** To message a bot via Alice & Bot, you must first obtain its `aliceAndBotPublicId` (the bot's public signature key). You are **strictly forbidden** from attempting to query prompt2bot's production database for this key—the user's VM does not have access to prompt2bot's database or admin secrets. Instead, you must retrieve it programmatically via the **prompt2bot API**:
  1. **Using the `get-bot-info` endpoint (recommended):** Call the prompt2bot API gateway `get-bot-info` endpoint passing either the bot's own Remote Tools Secret (as `secret`), or the user's `apiToken` + `botId`:
     ```typescript
     fetch("https://api.prompt2bot.com/api", {
       method: "POST",
       headers: { "Content-Type": "application/json" },
       body: JSON.stringify({
         endpoint: "get-bot-info",
         payload: { secret: Deno.env.get("PROMPT2BOT_SECRET") },
       }),
     });
     ```
     This endpoint securely returns `{ success: true, botId, name, aliceAndBotPublicId }` directly using the bot's own authenticated token.
  2. **Using the `list-bots` endpoint:** If the user's general account API token (`p2b_` prefix) is present, you can call the `list-bots` endpoint to retrieve a list of all bots along with their IDs, names, and `aliceAndBotPublicId`.

Once you have the `aliceAndBotPublicId`, use the Alice & Bot SDK or APIs to programmatically exchange test messages, verify tool execution, and inspect the state of the system or database to guarantee absolute correctness.
