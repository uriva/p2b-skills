---
name: p2b-make
description: Make.com integration guidance for prompt2bot agents — regional APIs, module versions, and scenario blueprint scanning.
---

# p2b-make

Make.com integration skill for prompt2bot agents.

## Instructions

You are helping a user build or edit Make.com scenarios programmatically via the
Make.com API. Never give the user manual UI instructions for Make.com — always
do it yourself through the API.

**Before any Make.com work, check if `MAKE_API_TOKEN` is stored using `list_env_variables`.** If missing, walk the user through getting it:
1. Go to https://www.make.com and log in
2. Click their profile icon → "API" or go to https://www.make.com/en/api-documentation
3. Create an API token with the scopes you need
4. Give you the token

Store it via `set_secret` as `MAKE_API_TOKEN` with hosts `["eu1.make.com", "eu2.make.com", "us1.make.com"]`. You will use it via `run_safescript` with `secretMapping`. NEVER use a VM.

**Once `MAKE_API_TOKEN` is present, immediately learn the `safescript` skill (by calling `learn_skill` with `skillName: "safescript"`) and call `run_safescript`** to fetch scenario blueprints (`GET https://eu1.make.com/api/v2/scenarios/<id>/blueprint`), list scenarios, inspect API endpoints, or test payloads. Do not stop or call `create_vm` — run Safescript!

When building or editing Make.com scenarios programmatically via the API:

- Make runs on regional subdomains: `eu1.make.com`, `eu2.make.com`, `us1.make.com`.
  If a valid token returns `401 Unauthorized` or `Access denied`, retry against
  other regional subdomains (especially `eu2.make.com`) before assuming the token
  is broken.

- **Module versions — scan before injecting.** When appending webhooks or editing
  scenarios programmatically, always default to the modern `http:MakeRequest`
  (version 4) module. Older modules like `http:ActionSendData` (version 3) can be
  silently deprecated by Make.com and cause `BundleValidationError` that pauses
  the scenario. Before choosing a module name/version, scan another active,
  working scenario in the same Make.com organization via the API and check which
  HTTP module version it uses. Use that verified version in your blueprint
  instead of guessing.

- **Servers called by Make must never return an HTTP error.** If Make calls your
  server and receives a 4xx or 5xx status code, it will shut down the entire
  automation scenario. Your server must always respond with a 2xx status code,
  even when the input is invalid. Communicate errors through the response body
  instead (e.g. `{ "ok": false, "error": "..." }`). The Make scenario should
  inspect the body to decide whether to continue or handle the error gracefully.

- **NEVER CALL `create_vm` FOR MAKE.COM OR API WORK (CRITICAL):** You are STRICTLY FORBIDDEN from calling `create_vm` or `run_command_on_vm` to fetch scenario blueprints, inspect REST APIs, or test JSON payloads. VMs trigger intrusive user-approval gates (`Approval Required for create_vm`) that break UX and cause user frustration. You MUST learn the `safescript` skill (`learn_skill` with `skillName: "safescript"`) and use `run_safescript` (or command `safescript/run_safescript`) for ALL HTTP requests, scenario queries, and API testing.

- **Use Safescript (`learn_skill` with `skillName: "safescript"`, then `run_safescript`) for ALL API calls, spec fetching, & payload testing (NO VM APPROVAL PROMPTS):**
  When checking Make.com scenario blueprints, listing scenarios, making REST API calls, testing custom HTTP calls, or fetching OpenAPI/Swagger specs for third-party services, ALWAYS learn the `safescript` skill (by calling `learn_skill` with `skillName: "safescript"`) and call `run_safescript` (or command `safescript/run_safescript`). DO NOT call `create_vm` or `run_command_on_vm` for API calls, payload testing, or spec fetching. Safescript executes instantly on the edge without triggering user-approval prompts (`Approval Required for create_vm`).

- **Schema-First Inspection Rule (Before Payload Construction):**
  When constructing, editing, or debugging custom HTTP/API payloads (e.g., custom HTTP calls to third-party services like SUMIT/OfficeGuy, Stripe, CRM APIs, etc.):
  1. Fetch and parse the official OpenAPI / Swagger definition or schema docs first using `safescript`.
  2. **Verify primitive data types explicitly:** Ensure numbers (e.g. enum integers like `SearchMode: 6`) are passed as numbers without quotes (`6` not `"6"` or `"EmailAddress (6)"`), booleans as raw `true`/`false`, and objects cleanly nested (`{ "Customer": { ... } }`).
  3. Never guess field names or enum values from human UI text or dropdown labels.

- **End-to-End Pipeline & Trigger Verification:**
  When troubleshooting scenario errors in Make.com:
  1. **Trigger check:** Confirm trigger configuration and starting points (e.g. Gmail module *"Choose where to start"*).
  2. **Lookup layer check:** Ensure prerequisite lookup modules exist to retrieve required downstream identifiers (e.g. fetching a recurring subscription ID before attempting a cancellation endpoint).
  3. **Action mapping check:** Confirm downstream modules receive valid, non-null mapped fields.

- **Protocol Success vs. Domain Success Disambiguation:**
  Distinguish between HTTP syntax validity (receiving HTTP 200 or valid JSON) and domain business success (e.g., `"Customer item not found"` means the API payload was parsed but the business operation failed). Do not report an integration task as resolved until both the schema parses AND the domain operation succeeds.

- **Type-Disambiguated Code Snippets:**
  When presenting JSON configurations for Make.com modules to users, format them in clear code blocks with exact non-string primitive types (e.g. `"SearchMode": 6`), accompanied by a note warning the user not to wrap numbers or booleans in quotes unless explicitly required.
