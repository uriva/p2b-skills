# VM and Secrets Management Guidelines

Guidelines for virtual machine environments, environment variables, pre-installed CLI tools, cost optimization, debugging, and secrets management.

---

## Cost Optimization & Resource Rules (CRITICAL)

- **Safescript is preferred for no-brainer operations and simple HTTP requests:** Utilizing Safescript is highly encouraged because it is more efficient, faster, and avoids the compute costs and latency of provisioning a VM. Use it whenever you need simple GET/POST requests, basic config lookups, or simple integrations.
- **Use a VM if it is considerably better:** If a task involves complex multi-step database operations, calling non-trivial SDKs (like `@instantdb/admin`), heavy data parsing, extensive pagination, or actual file system development tasks (writing multiple files, cloning/pushing repositories, installing packages, compiling, or running tests), you are encouraged to spin up and use a VM. Do not struggle with custom sandbox limitations if a VM provides a considerably better/safer implementation path.
- **Report uncomfortable or restrictive tooling:** If you find any tooling (such as Safescript syntax, limitations, missing functions, or policies) uncomfortable, buggy, or overly restrictive for the task at hand, do not spend hours fighting or guessing the syntax. Instead, **report a platform bug** explaining the discomfort and requesting an improvement, and immediately proceed to use a VM to complete the user's task.

---

## Workflow Decision (VM vs. Safescript)

- **When to use Safescript:** Simple or nested HTTP requests, fetching/posting JSON, basic string parsing, and secret mapping.
- **When to use a VM:** Actual development, file system tasks (writing TypeScript/JavaScript files, cloning/pushing repositories, installing packages, running tests), or any complex database operations (e.g. InstantDB admin transactions/pagination) where a VM with an SDK is considerably better.
- Before deploying or integrating with an external service, first read and analyze the target (fetch the URL, inspect API docs or HTML structure). Don't write integration code against assumptions — verify the actual interface first.
- If a deployment or integration fails twice on the same issue, stop retrying. Tell the user what failed and ask for specific information (logs or environment variables).

---

## Environment Secrets and Variables

- **Before asking the user for any secret, API key, or initiating an OAuth flow, call `list_env_variables` to check what's already stored.** It shows secret and variable names (not values). If a secret/token for the service you need (like `GITHUB_TOKEN` or `DENO_DEPLOY_TOKEN`) is already there, use it — don't ask or trigger authentication again. Only request credentials or trigger OAuth when nothing suitable is stored.
- **NEVER ASK THE USER FOR A GITHUB PERSONAL ACCESS TOKEN (PAT) OR GITHUB_TOKEN:** You must use the platform's OAuth tools instead. Call the `create_oauth_callback` tool with `provider: "github"`, `env_variable_name: "GITHUB_TOKEN"`, and scopes `["repo", "workflow"]`. Present the returned clickable authorization URL verbatim to the user. Once they authorize, call `check_oauth_result` with the state to verify. If repository access is missing, present the returned `github_install_url` verbatim so they can grant Prompt2Bot GitHub App permissions to their repository.
- **Never write secrets to files, environment variables, or inline in code.** When a user gives you an API key or token, always store it using the `set_secret` tool. This encrypts and stores the secret — it gets injected as a real environment variable on VM creation. If you put a secret in a file or embed it in a CLI command, it will be logged in conversation history in plaintext. Always use `set_secret`.

---

## How Secrets Work on the VM

Secrets stored via `set_secret` are injected as **real environment variables** on the VM. The env var name is the secret name, uppercased with dashes/spaces replaced by underscores (e.g. a secret named `github_token` becomes `$GITHUB_TOKEN`). The actual decrypted value is available — no placeholders, no proxy, no indirection.

```bash
# In shell
curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user

# In code
const token = Deno.env.get("GITHUB_TOKEN");
fetch("https://api.github.com/user", {
  headers: { "Authorization": `Bearer ${token}` },
});
```

**SDKs work normally.** Since the real value is available, you can pass secrets directly to SDK constructors:
```ts
import { init } from "npm:@instantdb/admin";
const db = init({
  appId: Deno.env.get("INSTANTDB_APP_ID")!,
  adminToken: Deno.env.get("INSTANTDB_ADMIN_TOKEN")!,
});
```

### Rules:
- **Always specify correct hosts/domains when calling `set_secret`:** When saving a secret using `set_secret`, you **MUST** populate the `hosts` parameter with the exact domains/hosts that your Safescript or sandbox code will call (e.g., `["api.github.com"]` for GITHUB_TOKEN, `["eu1.make.com", "eu2.make.com", "us1.make.com"]` for MAKE_API_TOKEN, etc.). Leaving this empty or incorrect will cause Safescript and sandbox proxy HTTP calls to fail or lose the secret value.
- **Never hardcode secret values in code or files.** Always read from env vars. Store secrets using `set_secret` so they persist across VM recreations.
- **Never log or print** env var values containing secrets — they contain real values and will appear in conversation history.
- **Before asking the user for a secret**, call `list_env_variables` to check what's already stored. Only ask when nothing suitable exists.
- **When a user gives you an API key or token**, always store it using `set_secret`. Never write it to a file or inline it in code.

### Troubleshooting:
If an API call fails with "Invalid token" or auth errors:
1. **Missing secret** — hasn't been stored yet. Ask the user to provide it.
2. **Wrong value** — expired token, typo, wrong scope. Ask the user to re-enter.
3. **Wrong env var name** — check with `list_env_variables` and use the exact name shown.
4. **Missing workflow or repository permissions on `GITHUB_TOKEN`** — GitHub Actions workflows silently fail to run if the token lacks the `workflow` scope, or if the Prompt2Bot GitHub App hasn't been installed on the repository. If a CI step didn't trigger, or push/clone fails, the OAuth flow may have been run without the correct scopes, or Prompt2Bot lacks repository access. Guide the user to re-authenticate with the correct scopes (`["repo", "workflow"]`) via `create_oauth_callback`, and check if they need to install the Prompt2Bot GitHub App on the repository using the `github_install_url`.

---

## VM Secrets vs Deno Deploy Env Vars

Both the VM and Deno Deploy use real environment variables. The difference is only how secrets are set:

| | VM | Deno Deploy |
|---|---|---|
| **How secrets are set** | `set_secret` tool | `deno deploy env set KEY=VALUE` |
| **How code accesses them** | `Deno.env.get("KEY")` / `$KEY` | `Deno.env.get("KEY")` / `$KEY` |
| **Real value available?** | Yes | Yes |

Code that reads secrets via `Deno.env.get()` works identically on both.

---

## CLI Tools on the VM

The VM has pre-installed CLIs for GitHub, Deno Deploy, and InstantDB. Secrets are injected as real environment variables, so all CLIs authenticate automatically.

### Required secrets (store via `set_secret`):
- `GITHUB_TOKEN` — GitHub access token. **NEVER ask the user to manually create a personal access token (PAT).** Instead, you must use the platform's OAuth flow to obtain it. Call the `create_oauth_callback` tool with `provider: "github"`, `env_variable_name: "GITHUB_TOKEN"`, and `scopes: ["repo", "workflow"]`. Present the returned `authorization_url` verbatim to the user as a clickable link. After they complete the OAuth flow, call `check_oauth_result` with the state to verify. The OAuth scopes ensure the token has the necessary permissions to work end-to-end:
  - **`repo`** — enables cloning, pushing, creating repos, managing files via the Contents API.
  - **`workflow`** — needed to trigger GitHub Actions CI runs (e.g., after pushing schema changes to InstantDB, triggering a deploy pipeline). Without this, CI steps in any repo you create or push to will silently fail to run. If repository access is missing or restricted, also send the `github_install_url` returned by `create_oauth_callback` so the user can install and grant the Prompt2Bot GitHub App access to the target repositories.
- `DENO_DEPLOY_TOKEN` — Deno Deploy token starting with `ddo_`
- `INSTANTDB_ADMIN_TOKEN` — InstantDB admin token

### Required variables (store via `set_env_variable` — plain values, not secrets):
- `INSTANTDB_APP_ID` — InstantDB app UUID

### `gh` — GitHub CLI
The `gh` CLI is pre-configured with `GH_TOKEN` from the environment.
```bash
gh auth status                    # Show authenticated user
gh repo list                     # List your repos
gh repo create <name> --private  # Create private repo (MANDATORY: always create private repos)
gh issue list                    # List issues
gh pr create                     # Create a pull request
gh api /user                     # Raw API call
```

**Git operations** (clone, push, pull) work normally with the `GITHUB_TOKEN` env var. You can also use the GitHub Contents API via curl:
```bash
# Download a file from a repo
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  "https://api.github.com/repos/<owner>/<repo>/contents/<path>" \
  | jq -r '.content' | base64 -d > <local-path>

# Create/update a file via the API
curl -s -X PUT -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "Content-Type: application/json" \
  "https://api.github.com/repos/<owner>/<repo>/contents/<path>" \
  -d "{\"message\": \"commit message\", \"content\": \"$(base64 -w0 <local-path>)\"}"
```

### `deno deploy` — Deno Deploy (native subcommand, NOT `deployctl`)
**CRITICAL: The command is `deno deploy`, a built-in subcommand of the `deno` binary. NEVER use `deployctl` — it is a deprecated standalone CLI.** Do not install it (`deno install jsr:@deno/deployctl`), do not run it, do not fall back to it. If `deno deploy` fails, report the error — do not try `deployctl` as an alternative.

**Before doing any work with Deno Deploy (including listing apps, creating apps, deploying, or setting env variables), you MUST immediately call `learn_skill("p2b-deno-deploy")` to load the complete Deno Deploy guidelines and CLI reference.**

The VM is pre-configured with `DENO_DEPLOY_TOKEN` in the environment, so `deno deploy` authenticates automatically.

```bash
deno deploy --app=<slug> --prod                      # Deploy current directory
deno deploy create <slug>                            # Create an app
deno deploy env add <KEY> "<VALUE>" [--secret]       # Set a plain text or secret environment variable
deno deploy env load <file_path> [--non-secrets ...] # Load variables from a .env file (treats as secrets by default)
deno deploy env list                                 # List environment variables
deno deploy env update-value <KEY> "<VALUE>"         # Update the value of an existing variable
deno deploy env delete <KEY>                         # Delete an environment variable
deno deploy logs --app=<slug>                        # Tail logs (live stream - will hang in non-interactive VM)
```

---

## Webhook & Integration Debugging (CRITICAL)

When a custom tool fails or an integration doesn't seem to work, you must inspect the application logs on Deno Deploy.

- **Never fabricate or lie about delivery or integration failures:** If a test message, webhook, or scheduled action fails to deliver, **NEVER** fabricate technical explanations or invent system myths (such as claiming a phone number is in a "Cold State", or that the WhatsApp server is "sleeping" and needs a "Hi" message to wake it up). If you don't know why a message failed to deliver, be exceptionally honest and transparent. State that you do not know the exact reason yet, and guide the user to check real logs, Deno Deploy log historical slices, or DB task queue states.
- **Ensure custom tool schemas are Gemini-safe (CRITICAL):** When writing JSON schemas or parameters for custom/remote tools, be extremely careful: **Gemini does NOT support `anyOf`, `oneOf`, or nested `const` in function declarations.** Always define flat, simple, strongly-typed parameters (like strings, booleans, arrays, or numbers) with flat `enum` types instead of complex union types (like `z.union`) to prevent terminal Google API schema-validation crashes (`INVALID_ARGUMENT` / `Unknown name "const" / Cannot find field`).
- **Verify channel capabilities and tokens before testing (WhatsApp):** Before doing any work with WhatsApp integrations, you MUST learn the `p2b-whatsapp` skill to understand official/unofficial integration paths, token configuration, and template/capability constraints. Programmatically verify that the target bot actually has its WhatsApp for Business Token (`whatsappForBusinessToken`) or other necessary tokens configured in InstantDB before claiming that a message flow is working.
- **Never use standard live-stream tail commands:** Running raw `deno deploy logs --app=<slug>` opens an infinite live connection. This will hang in a non-interactive VM, resulting in timeouts or connection-read errors (e.g., `TypeError: error reading a body from connection`).
- **Fetch historical log slices instead:** To debug errors and see past logs (for example, to inspect the HTTP 400 error payload from 5 minutes ago), always fetch a specific window of historical logs using the `--start` and `--end` flags. The command will output the logs in that window and immediately terminate:
  ```bash
  # Get historical logs for the last 15 minutes and immediately exit:
  deno deploy logs --app=<slug> --start="$(date -u -d '15 minutes ago' +'%Y-%m-%dT%H:%M:%SZ')" --end="$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  ```
- **Never guess dashboard states on empty/failed logs:** If you cannot find any logged requests or if log-fetching fails, **do not assume** the tool has been turned off or disabled in the user's dashboard. Do not ask the user for screenshots of the settings page or instruct them to check dashboard toggles. Instead, programmatically check your local code configuration:
  1. Call `get-bot-info` using the API to inspect the actual list of registered tools, URLs, and active prompt of your bot on Prompt2Bot.
  2. Ensure your local custom tool schemas and handler routes match the wrapped payload format (`body.payload.params`), rather than parsing properties from the top-level body.
  3. Verify that the webhook URL registered on Prompt2Bot matches the actual deployed URL of your server.

To set environment variables on Deno Deploy, use the native `deno deploy env add <KEY> "<VALUE>"` command on the VM (optionally passing the `--secret` flag to mask the value in the console, or specifying `--org <org_slug> --app <app_slug>` if running from outside the project directory). To load an entire `.env` file, use `deno deploy env load <file_path>` (all loaded values are treated as secrets by default). Calling `deno.json` or CLI commands under the app directory will auto-infer the organization and app name if configured.

`deno deploy --app=<slug> --prod` is the standard way to deploy. It does diff-sync file upload, tracks the build via SSE (building -> warming -> routing), and prints the final URL. No entrypoint argument needed if there's a `deno.json` with a `start` task or a `main.ts` in the project root.

**Do not reimplement Deno Deploy.** Do not write custom scripts that clone the CLI internals, call hidden tRPC mutations directly, or manually reproduce the diffsync upload protocol. The correct path is: discover the exact org/app slug, then run `deno deploy --app=<slug> --prod`. If it fails, report the exact command and full stderr to the user and stop.

Note: `deno deploy` may create a `deno.jsonc` config file in the project directory after the first deployment — this is normal.

### Listing apps in an org
The `deno deploy` CLI has no `list` subcommand. To discover which apps exist, use curl against the tRPC API at `console.deno.com`. The tRPC API authenticates via cookies, not `Authorization: Bearer`:
```bash
# List orgs
curl -s -H "Cookie: token=$DENO_DEPLOY_TOKEN; deno_auth_ghid=force" \
  "https://console.deno.com/api/orgs.list?batch=1&input=%7B%220%22%3A%7B%7D%7D"

# List apps in an org
curl -s -H "Cookie: token=$DENO_DEPLOY_TOKEN; deno_auth_ghid=force" \
  "https://console.deno.com/api/apps.list?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22org%22%3A%22ORG_SLUG%22%7D%7D%7D"
```
Replace `ORG_SLUG` with the org slug from the `orgs.list` response.

**Mandatory rule: list before deploy.** Before the **first** deploy attempt for a project, or anytime you are not 100% certain of the org slug and app slug, you must run `orgs.list` and then `apps.list`. Do not guess app or org slugs.

### Direct HTTP calls to the Deno Deploy REST API
For operations the CLI doesn't support, use the v2 API. The v1 API (`/v1/`) rejects `ddo_` tokens.
```bash
# Delete an app
curl -s -X DELETE \
  -H "Authorization: Bearer $DENO_DEPLOY_TOKEN" \
  "https://api.deno.com/v2/apps/<app-slug>"

# List all apps
curl -s \
  -H "Authorization: Bearer $DENO_DEPLOY_TOKEN" \
  "https://api.deno.com/v2/apps"
```
The base path is always `/v2/` — "projects" are called "apps" and "deployments" are called "revisions".

### `instant-cli` — InstantDB CLI
The VM is pre-configured with `INSTANT_CLI_API_URI` and `INSTANT_APP_ADMIN_TOKEN` environment variables. The app ID is available as `$INSTANTDB_APP_ID`.
```bash
instant-cli query '{"users": {}}' --app $INSTANTDB_APP_ID         # Query
instant-cli push --app $INSTANTDB_APP_ID                           # Push schema + perms
instant-cli push schema --app $INSTANTDB_APP_ID                    # Push schema only
instant-cli push perms --app $INSTANTDB_APP_ID                     # Push perms only
instant-cli pull --app $INSTANTDB_APP_ID                           # Pull schema + perms
```

**Transact (database writes):** The CLI lacks a `transact` command, so use curl:
```bash
curl -s -X POST "https://api.instantdb.com/admin/transact" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $INSTANTDB_ADMIN_TOKEN" \
  -d "{\"app_id\": \"$INSTANTDB_APP_ID\", \"steps\": [[\"update\", \"users\", \"<id>\", {\"name\": \"test\"}]]}"
```

### When to use CLIs vs curl
Use `gh` for GitHub operations. Use `deno deploy` for all Deno Deploy operations. Use `instant-cli` for InstantDB queries, schema, and perms — use curl for transact. Use curl or fetch only for services that don't have a CLI or for InstantDB transact operations.

---

## CI-Only for Deployments and Schema Pushes

**Never run `deno deploy` or `instant-cli push` manually on the VM.** The VM is ephemeral — it can be deleted at any time, which means any manually triggered deployment disappears with it. Both Deno Deploy and InstantDB schema pushes must be done via **CI** (GitHub Actions), not via direct CLI on the VM.

### Correct Pattern:
1. On the VM, write and test code.
2. Push changes to GitHub (via Contents API or `gh`).
3. Set up a GitHub Actions workflow in the repo that runs `deno deploy --app=<slug> --prod` or `instant-cli push` on every push to `main`. The workflow runs on GitHub's infrastructure, not the VM, so it persists regardless of what happens to the VM.
4. Merging or pushing to `main` triggers the workflow, which deploys or pushes the schema.

**If the repo doesn't have a CI workflow yet**, create one:
```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: denoland/setup-deno@v1
        with:
          deno-version: 2.x
      - run: deno deploy --app=<slug> --prod
        env:
          DENO_DEPLOY_TOKEN: ${{ secrets.DENO_DEPLOY_TOKEN }}
```

For InstantDB, the same pattern applies — add `instant-cli push` to a workflow step, and set `INSTANTDB_APP_ID` + `INSTANTDB_ADMIN_TOKEN` as repo secrets.

**Common mistake to avoid:** Running `deno deploy --prod` directly on the VM to "test the deployment". It works in the moment, but the next time the VM is recreated (or destroyed), the deployment is gone. Always push to GitHub and let CI handle it.

---

## Coding Workflow on the VM

**Always use the todo tool** (belonging to the `todo` skill) to plan and track your work. Before calling `todo/todo_write` for the first time, you must call `learn_skill("todo")` to load its exact schema and instructions. Before writing any code, capture the task as todo items. Mark each item in_progress when you start it and completed when done. This gives the user visibility into your progress and prevents you from forgetting steps.

When working on code on a VM, follow this structured approach:
1. **Understand** — Before changing anything, read existing code and check for project-level conventions.
   - **Check for instruction files:** FIRST, look for an `AGENTS.md` at the repository root and in any subdirectory you will edit. Also check for `CLAUDE.md`, `.cursor/rules`, `.github/copilot-instructions.md`, and `README`.
   - **Treat instructions as mandatory:** Read the full `AGENTS.md` with `read_file` and treat it as mandatory project instructions that override your defaults. Read and follow these instructions before editing files, running builds, running tests, or committing changes.
   - Use `read_file` to examine files and `grep_files` to search for relevant patterns across the codebase to understand the local context.
2. **Plan** — Follow the "Planning, Technical Design & Threaded Implementation" workflow: write natural language and technical design docs in Markdown inside the GitHub repository, devise a test plan with a breakdown of requirements, consult a stronger model for feedback, obtain explicit user confirmation, and break the implementation tasks down into todo items using the todo tool.
3. **Implement** — Make changes using the file tools:
   - Use `read_file` before editing to see exact content with line numbers.
   - Use `edit_file` for targeted changes — it does exact string replacement, so provide enough surrounding context to make matches unique.
   - Use `write_file` only for new files or complete rewrites.
   - Use `glob_files` to discover project structure (e.g. `**/*.ts`, `src/**/*.tsx`).
   - Use `grep_files` to find all occurrences of a pattern before renaming or refactoring.
4. **Verify** — After changes, run the project's build/test commands via `run_command_on_vm` to confirm everything works.

**Prefer file tools over raw shell commands** for file operations. The file tools handle escaping, truncation, and error reporting correctly. Reserve `run_command_on_vm` for actual system commands: running builds, installing packages, git operations, starting servers, curl requests, etc.

---

## Anti-Pattern: Running Production Services on a Persistent VM

**Never run a user-facing server (API, webhook endpoint, web app) on a persistent VM.** The VM is your development workspace — a disposable box for coding, running `gh` / `instant-cli` / `deno deploy`, and building. It is NOT a hosting platform. It can be destroyed at any time (1 hour idle, manual destroy, provisioning churn) and everything on it disappears. When a VM with a "prod" server on it dies, the user's service goes down and they have no idea why.

**CRITICAL MANDATE — NO TOKENS, NO CODE EXECUTION SHORTCUTS:** If the user has not provided a `GITHUB_TOKEN` or a `DENO_DEPLOY_TOKEN` (check using `list_env_variables` first), you are **strictly forbidden** from writing code directly to the VM and running it in the background as a "shortcut" to show them a working bot. This is a trap! Because the VM is ephemeral and will expire after 1 hour of inactivity, doing so will permanently delete the user's code and take their service offline. Instead, you must stop immediately, explain clearly and politely in simple terms why a GitHub account and a Deno Deploy account are required for permanent, 24/7 hosting, and guide them through authentication. For GitHub, initiate the OAuth flow using the `create_oauth_callback` tool with scopes `["repo", "workflow"]`. For Deno Deploy, guide them to get the token. Do not proceed to build any code until they complete the authentication so we can do it correctly via CI/CD and Git.

### Where production services go:
- **Anything long-running or user-facing** → deploy it to Deno Deploy via CI (`deno deploy --app=<slug> --prod`). Static apps, APIs, webhook handlers, Next.js apps, tool servers — all of these.
- **Quick demo or throwaway URL to share briefly** → use the ephemeral sandbox's `run_web_service` tool. It spins up a short-lived public HTTPS URL (minutes, not hours). Perfect for "can you show me a quick preview?".

Do not use `run_command_on_vm "deno run --allow-net server.ts &"` or similar to leave a server running on the VM in the background. If you catch yourself reaching for that, stop and deploy instead.

**Never share the VM's IP address with the user.** The IP is an implementation detail of your dev environment — not a public endpoint. Telling the user "your service is at http://46.x.x.x:8080" will:
- Stop working the moment the VM is recreated (new IP)
- Leave the user pointing at a stranger's server when Hetzner recycles the IP
- Encourage the anti-pattern above (treating the VM as a host)

If you need to give the user a URL, the answer is always a proper domain pointing at Deno Deploy (or an ephemeral sandbox URL for quick demos). If the user asks for the VM's IP, push back: "The VM is my workspace, not a hosting platform — I'll deploy this to Deno Deploy and send you the real URL."

---

## Anti-Pattern: Exposing Secrets in HTTP Endpoints/URLs

**Never build HTTP endpoints (like setup/webhook routes) that accept API tokens, keys, or secrets in URL search/query parameters, URL paths, headers, or request bodies.**
- Exposing secrets in URL parameters is a severe security vulnerability. They leak in browser history, server logs, reverse proxy logs, and `Referer` headers.
- Exposing endpoints that accept a secret from the request and then run actions with it (like configuring prompts or sending messages) allows anyone who finds the endpoint to hijack or abuse your bot.
- **The Correct Pattern:** Always read all secrets (e.g., `P2B_API_TOKEN`, `INSTANTDB_ADMIN_TOKEN`, etc.) directly from the server's environment variables (e.g., `Deno.env.get("P2B_API_TOKEN")`). If a script/endpoint needs to run a setup or privileged action, it should either be triggered locally/via CI, or verify the request using a securely stored signature/HMAC, never by having the user pass the raw secret in the request URL.

---

## Platform Boundaries & External Integration Guidelines

- **Secret & Token Transfers (Platform vs External Hosts):**
  - Decrypted secrets (via `set_secret`) and OAuth tokens are available **only** inside your platform VM and sandboxes.
  - You can programmatically provision these to supported platforms (e.g., transferring to Deno Deploy via `deno deploy env set KEY=$KEY`).
  - You **cannot** automatically inject secrets/tokens into external environments lacking programmatic provisioning APIs (e.g., local user PCs, Streamlit Cloud, etc.). Instead, textually guide the user to configure their own local `.env` files or hosting dashboard. Never commit raw secrets to files.
- **OAuth Scope Limitation:**
  - `create_oauth_callback` only authenticates actions executing on your platform's backend. Do not claim you can generate inline OAuth consent links to authenticate the user's _local_ or _externally hosted_ applications.
- **Mock UI Components:**
  - When generating local dashboards, interfaces, or scripts containing mock chat inputs, never claim they are synchronized in real-time with your active chat session. Clearly state that local UI components are static mocks/placeholders and they must continue chatting in the main conversation window.
- **Allowed Developer URLs:**
  - The following standard reference links are considered part of your ground truth and can be shared verbatim:
    - `https://share.streamlit.io` (Streamlit Cloud dashboard)
    - `https://github.com/settings/tokens/new` (GitHub PAT generation)
    - `https://github.com/settings/tokens` (GitHub PAT management)
