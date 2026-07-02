# CLI Tools & Deno Deploy Operations on the VM

Reference for the pre-installed CLIs (`gh`, `deno deploy`, `instant-cli`), how to
call them, and how to debug Deno Deploy. For how secrets are injected and stored,
see `vm-and-secrets.md`. For the credential-acquisition policy (GitHub OAuth,
never a PAT), see `web-app-playbook.md` and `vm-and-secrets.md`. Deployments and
schema pushes must run in CI, not on the VM — see `planning-and-design.md` and
the "CI-Only for Deployments" section in `vm-and-secrets.md`.

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

**Before doing any work with Deno Deploy (including listing apps, creating apps, deploying, or setting env variables), you MUST acquire and activate the dedicated Deno Deploy skill (`p2b-deno-deploy`), which holds the complete Deno Deploy guidelines and CLI reference.** If that skill is already among your available skills, learn it. If it is not available yet, install it from the community registry (Tank) first, then learn it. Do not attempt any Deno Deploy work from general knowledge — its guidelines are mandatory.

The VM is pre-configured with `DENO_DEPLOY_TOKEN` in the environment, so `deno deploy` authenticates automatically. The VM's `deno deploy` is the base-image shim (≥ 0.0.9902): it exits 0 after a successful deploy and supports `logs --once` (drain then exit). Pass `--non-interactive` for scripted create/deploy.

```bash
deno deploy --app=<slug> --prod --non-interactive           # Deploy current directory (exits 0 on success)
deno deploy create <slug> --non-interactive                 # Create an app
deno deploy env add <KEY> "<VALUE>" [--secret]       # Set a plain text or secret environment variable
deno deploy env load <file_path> [--non-secrets ...] # Load variables from a .env file (treats as secrets by default)
deno deploy env list                                 # List environment variables
deno deploy env update-value <KEY> "<VALUE>"         # Update the value of an existing variable
deno deploy env delete <KEY>                         # Delete an environment variable
deno deploy logs --app=<slug> --once                 # Capture current logs then exit (bounded; bare `logs` tails forever)
```

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

## Webhook & Integration Debugging (CRITICAL)

When a custom tool fails or an integration doesn't seem to work, you must inspect the application logs on Deno Deploy.

- **Never fabricate or lie about delivery or integration failures:** If a test message, webhook, or scheduled action fails to deliver, **NEVER** fabricate technical explanations or invent system myths (such as claiming a phone number is in a "Cold State", or that the WhatsApp server is "sleeping" and needs a "Hi" message to wake it up). If you don't know why a message failed to deliver, be exceptionally honest and transparent. State that you do not know the exact reason yet, and guide the user to check real logs, Deno Deploy log historical slices, or DB task queue states.
- **Ensure custom tool schemas are Gemini-safe (CRITICAL):** When writing JSON schemas or parameters for custom/remote tools, be extremely careful: **Gemini does NOT support `anyOf`, `oneOf`, or nested `const` in function declarations.** Always define flat, simple, strongly-typed parameters (like strings, booleans, arrays, or numbers) with flat `enum` types instead of complex union types (like `z.union`) to prevent terminal Google API schema-validation crashes (`INVALID_ARGUMENT` / `Unknown name "const" / Cannot find field`).
- **Verify channel capabilities and tokens before testing (WhatsApp):** Before doing any work with WhatsApp integrations, you MUST learn the `p2b-whatsapp` skill to understand official/unofficial integration paths, token configuration, and template/capability constraints. Programmatically verify that the target bot actually has its WhatsApp for Business Token (`whatsappForBusinessToken`) or other necessary tokens configured in InstantDB before claiming that a message flow is working.
- **Never use standard live-stream tail commands:** Running raw `deno deploy logs --app=<slug>` opens an infinite live connection. This will hang in a non-interactive VM, resulting in timeouts or connection-read errors (e.g., `TypeError: error reading a body from connection`).
- **Use `--once` (or a `--start`/`--end` window) for bounded logs:** The VM CLI (≥ 0.0.9902) supports `--once`, which drains the currently-available logs and then exits — the right default for a non-interactive VM. Add `--start`/`--end` to widen or bound the window. Both terminate on their own:
  ```bash
  # Drain the last hour of logs and exit:
  deno deploy logs --app=<slug> --once
  # Or a specific 15-minute window (also exits immediately):
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
Replace `ORG_SLUG` with the org slug from the `orgs.list` response. The `p2b-deno-deploy` skill covers deriving the org from the token — do not ask the user for it.

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
