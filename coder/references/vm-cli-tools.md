# CLI Tools & Service Debugging on the VM

Reference for the pre-installed CLIs (`gh`), how to
call them, and how to debug integrations and services. For how secrets are injected and stored,
see `vm-and-secrets.md`. For the credential-acquisition policy (GitHub OAuth,
never a PAT), see `web-app-playbook.md` and `vm-and-secrets.md`. Deployments
must run in CI, not on the VM — see `planning-and-design.md` and
the "CI-Only for Deployments" section in `vm-and-secrets.md`.

---

## CLI Tools on the VM

The VM has pre-installed CLIs for GitHub (`gh`). Secrets are injected as real environment variables, so CLIs authenticate automatically.

### Required secrets (store via `set_secret`):
- `GITHUB_TOKEN` — GitHub access token. **NEVER ask the user to manually create a personal access token (PAT).** Instead, you must use the platform's OAuth flow to obtain it. Call the `create_oauth_callback` tool with `provider: "github"`, `env_variable_name: "GITHUB_TOKEN"`, and `scopes: ["repo", "workflow"]`. Present the returned `authorization_url` verbatim to the user as a clickable link. After they complete the OAuth flow, call `check_oauth_result` with the state to verify. The OAuth scopes ensure the token has the necessary permissions to work end-to-end:
  - **`repo`** — enables cloning, pushing, creating repos, managing files via the Contents API.
  - **`workflow`** — needed to trigger GitHub Actions CI runs (e.g., triggering a deploy pipeline). Without this, CI steps in any repo you create or push to will silently fail to run. If repository access is missing or restricted, also send the `github_install_url` returned by `create_oauth_callback` so the user can install and grant the Prompt2Bot GitHub App access to the target repositories.

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

### When to use CLIs vs curl
Use `gh` for GitHub operations. Use curl or fetch for services that don't have a dedicated CLI.

---

## Webhook & Integration Debugging (CRITICAL)

When a custom tool fails or an integration doesn't seem to work, you must inspect the application and server logs.

- **Never fabricate or lie about delivery or integration failures:** If a test message, webhook, or scheduled action fails to deliver, **NEVER** fabricate technical explanations or invent system myths (such as claiming a phone number is in a "Cold State", or that the WhatsApp server is "sleeping" and needs a "Hi" message to wake it up). If you don't know why a message failed to deliver, be exceptionally honest and transparent. State that you do not know the exact reason yet, and guide the user to check real logs or task queue states.
- **Ensure custom tool schemas are Gemini-safe (CRITICAL):** When writing JSON schemas or parameters for custom/remote tools, be extremely careful: **Gemini does NOT support `anyOf`, `oneOf`, or nested `const` in function declarations.** Always define flat, simple, strongly-typed parameters (like strings, booleans, arrays, or numbers) with flat `enum` types instead of complex union types (like `z.union`) to prevent terminal Google API schema-validation crashes (`INVALID_ARGUMENT` / `Unknown name "const" / Cannot find field`).
- **Verify channel capabilities and tokens before testing (WhatsApp):** Before doing any work with WhatsApp integrations, you MUST learn the `p2b-whatsapp` skill to understand official/unofficial integration paths, token configuration, and template/capability constraints. Programmatically verify that the target bot actually has its WhatsApp for Business Token (`whatsappForBusinessToken`) or other necessary tokens configured before claiming that a message flow is working.
- **Inspect bounded logs:** Avoid running indefinite live streaming tail commands that hang non-interactive environments. Use bounded log queries, timestamp filters, or specific log windows when fetching deployment or server logs.
- **Never guess dashboard states on empty/failed logs:** If you cannot find any logged requests or if log-fetching fails, **do not assume** the tool has been turned off or disabled in the user's dashboard. Do not ask the user for screenshots of the settings page or instruct them to check dashboard toggles. Instead, programmatically check your local code configuration:
  1. Call `get-bot-info` using the API to inspect the actual list of registered tools, URLs, and active prompt of your bot on Prompt2Bot.
  2. Ensure your local custom tool schemas and handler routes match the wrapped payload format (`body.payload.params`), rather than parsing properties from the top-level body.
  3. Verify that the webhook URL registered on Prompt2Bot matches the actual deployed URL of your server.
