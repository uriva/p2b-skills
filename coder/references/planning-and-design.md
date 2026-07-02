# Planning, Architecture and Design Guidelines

Before starting the implementation of any project or significant feature, you must rigorously design and verify your approach using this structured workflow.

Related references (load as needed):
- `tech-stack.md` — default tech choices, Next.js on Deno Deploy, project structure.
- `bot-architecture.md` — putting behavior in prompts, the prompt2bot API, `remote_config`, state-machine anti-pattern.
- `scheduling-and-media.md` — webhooks/cron/QStash scheduling, multimodal media, spreadsheet anti-pattern, WhatsApp pointer.

---

## Planning, Technical Design & Threaded Implementation

Before starting the implementation of any project or significant feature, you must rigorously design and verify your approach using this structured workflow. **All design, planning, and testing documents must be written in Markdown files directly inside the project's GitHub repository** (e.g., under a `docs/` directory or as design documents in the root) to serve as the version-controlled source of truth.

1. **Natural Language Planning & Breakdown:**
   - First, write a complete plan in natural language.
   - **User Description:** Draft a high-level, clear description of the feature or project tailored for non-technical, non-tech-savvy users. This is your primary way of communicating the project's goals, scope, and behavior to the user.
   - **Meticulous Technical Details:** Alongside the user description, specify meticulous technical implementation details (architecture, database schema, API contracts, directories, files to modify) for developers. This must be as detailed and precise as possible.

2. **Testing Plan & Individual Units:**
   - Devise a comprehensive testing plan to self-verify your work.
   - Break down the requirements into self-contained, individual units that can be tested independently.
   - Explicitly note subtleties, potential edge cases, risks, constraints, and things to look out for in the planning and testing documents.

3. **Stronger Model Consultation:**
   - Once you have written and pushed these planning and design documents (Markdown files) to the GitHub repository, you **MUST** consult at least once with a stronger model (e.g., by spawning a child thread/subagent with a meticulous prompt) to review, critique, and confirm your design plans.
   - Revise and refine the documents based on this expert architectural feedback.

4. **User Confirmation:**
   - Only after confirming the plan with the stronger model should you present the natural language version of the plan to the user.
   - Seek and obtain the user's explicit confirmation of the plan before starting any code implementation.

5. **Threaded Implementation:**
   - Once the user has confirmed the plan, begin implementation.
   - To ensure maximum efficiency, isolation, and safety, break the work into individual parts and delegate those parts to separate threads (subagents / child threads).

---

## Thread Delegation (Subagents)

When faced with complex, multi-step tasks or open-ended research, you can spawn autonomous child threads using the `run_in_new_thread` tool from the `automation` skill.

**CRITICAL:** Before calling the `automation/run_in_new_thread` tool, you **MUST** first learn/activate the `automation` skill to load its exact schemas and instructions into your active context. Never try to invoke `automation/run_in_new_thread` without learning the `automation` skill first, otherwise you won't have its schema and will hallucinate its parameters!

**When to use child threads:**
- To execute independent units of work in parallel (you can launch multiple child threads concurrently).
- For open-ended codebase exploration that requires multiple rounds of searching and reading.
- For complex refactoring or integration tasks that involve many steps.

**When NOT to use child threads:**
- For simple file reads or single `grep`/`glob` searches. Do these directly.
- For trivial tasks that don't require autonomous multi-step reasoning.

**How to prompt child threads:** Child threads start with a completely fresh context. Ensure that all formatting, goals, intents, verification steps, and return formats are written as structured natural language/markdown text *within the prompt itself* (do not pass these sections as separate JSON parameter keys to `run_in_new_thread`):
1. **Context & Goal**: Provide all necessary background information and clearly define the end goal.
2. **Intent**: Explicitly state whether the child thread is expected to _write code/modify files_ or _just do research_ (read/search).
3. **Verification**: Tell the child thread how to verify its work (e.g., "run `deno test` after making changes").
4. **Return Format**: Specify exactly what information the child thread must return back to you via its `end_thread_with_result` tool.

**Handling the result:** The child thread's work and its final result are **not visible to the user**. Once the child thread completes and returns its result to you, you must read that result and provide a concise summary or next steps back to the user. You can generally trust the output provided by the child thread.

---

## Two-Legged Systems: GitHub (CI) as the Source of Truth

Most non-trivial bots are **two-legged**:
1. **Rep agent** — the prompt2bot bot itself. It owns the system prompt, the tool registry, and the conversation loop.
2. **Backend server** — a Deno Deploy service owned by you. It hosts the HTTP tool endpoints the bot calls, runs recurring jobs, handles webhooks, and stores business data.

The two legs talk to each other over signed HTTP: the prompt2bot server calls your backend's tool endpoints; your backend calls prompt2bot's API (`setPrompt`, `setCustomTools`, `createRemoteTask`, `injectContext`, etc.). See `bot-architecture.md` for the full prompt2bot API reference.

### The Golden Principle: GitHub is the Ultimate Source of Truth
When building or integrating with agents that use remote skills or tools, **you MUST have a CI pipeline in GitHub that keeps the tools and skills in sync with the server.** The same applies to the agent's system prompt. Because of this requirement, we always prefer GitHub as the single, version-controlled source of truth.

- **Why?** Relying on manual updates or treating any dashboard as the source of truth leads to configuration drift, desynchronized routes, and broken agent behaviors. A GitHub Actions pipeline ensures that tool schemas, skill configurations, system prompts, and server handlers are deployed atomically and kept in perfect sync.
- **Never ask users to paste prompts or tools into the dashboard by hand.**
- Both the backend server and the bot's prompt/tools should be configured by CI on push to `main`:
  - **Backend code** is deployed to Deno Deploy automatically on push (GitHub integration).
  - **Automated InstantDB Schema & Perms Push:** If the application uses InstantDB, you **MUST** include an automated step in your GitHub Actions deployment pipeline (`deploy.yml`) that executes **`instant-cli push`** to automatically deploy the latest database schemas and permissions to production on every push to `main`. Never rely on manual database updates.
  - **Bot prompt and custom tools** are pushed by a CI step that calls `setPrompt` and `setCustomTools` against the prompt2bot API, using the bot's Remote Tools Secret stored as a GitHub Actions secret.

This keeps the bot's behavior version-controlled, reviewable in PRs, and reproducible across environments. The dashboard becomes a read-only view for debugging, not a place where configuration lives.

### Deployment Verification (CRITICAL)
- **Never claim a deployed service is running or live based on assumptions or simply because the code was pushed to main.**
- You **MUST** write and execute a quick script (using Safescript or any code execution tool) that performs an HTTP `fetch` against the deployed endpoint.
- Verify that the live endpoint actually responds successfully with a `200 OK` status before presenting the link or announcing completion to the user. If it fails with `404` or `503`, check if repository secrets are missing, wait for JSR CDN propagation, or guide the user on necessary steps.

**Typical repo layout for a two-legged system:**
```
my-bot/
  backend/              # Deno Deploy service
    tools/              # HTTP tool handlers
    main.ts
  bot/
    prompt.md           # source of truth for the bot's system prompt
    tools.ts            # source of truth for the tool registry
  .github/workflows/
    deploy.yml          # pushes prompt + tools to prompt2bot on every main push
```

**CI step that syncs the bot config** (runs after the backend is deployed so tool URLs point at live code):
```yaml
- name: Sync bot config to prompt2bot
  env:
    P2B_SECRET: ${{ secrets.P2B_BOT_SECRET }}
    BOT_ID: ${{ secrets.P2B_BOT_ID }}
  run: deno run -A scripts/syncBotConfig.ts
```

```ts
// scripts/syncBotConfig.ts
const prompt = await Deno.readTextFile("bot/prompt.md");
const { tools } = await import("../bot/tools.ts");

const api = (endpoint: string, payload: unknown) =>
  fetch("https://api.prompt2bot.com/api", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ endpoint, payload }),
  }).then((r) => r.json());

await api("set-prompt", {
  secret: Deno.env.get("P2B_SECRET"),
  botId: Deno.env.get("BOT_ID"),
  prompt,
});
await api("set-custom-tools", {
  secret: Deno.env.get("P2B_SECRET"),
  botId: Deno.env.get("BOT_ID"),
  tools,
});
```
