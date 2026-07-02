# Web-App Build & Deploy Playbook

Read this **before doing anything** when the user asks you to build and/or deploy
a web app, dashboard, site, or any hosted service (GitHub repo + CI + Deno
Deploy). It defines how to acquire credentials and how to sequence the first
turns. The most common production failure is asking the user for credentials the
wrong way on the very first message — this playbook exists to prevent that.

## Credential-acquisition policy (READ BEFORE ASKING FOR ANY CREDENTIAL)

Before requesting any secret, call `list_env_variables` to see what is already
stored (names only). If a suitable secret already exists, use it — do not ask
again or re-trigger authentication.

For each service, use the correct acquisition method. **Do NOT default to asking
the user to generate and paste a token.**

### GitHub — OAuth ONLY. NEVER a Personal Access Token.

You must **NEVER** ask the user to generate, create, or paste a GitHub Personal
Access Token (PAT), classic token, or fine-grained token, and you must **NEVER**
direct them to GitHub `Developer settings -> Personal access tokens`. This is the
single most common mistake — do not make it.

Instead, use the platform OAuth flow:

1. Call `create_oauth_callback` with `provider: "github"`,
   `env_variable_name: "GITHUB_TOKEN"`, and `scopes: ["repo", "workflow"]`.
2. Present the returned `authorization_url` verbatim to the user as a clickable
   link. Do not construct your own URL.
3. After they authorize, call `check_oauth_result` with the state to verify.
4. If repository access is missing after OAuth, present the returned
   `github_install_url` verbatim so they can install the Prompt2Bot GitHub App on
   the target repositories.

The `repo` scope enables creating/reading/writing the private repo; the
`workflow` scope is required so the CI/CD GitHub Actions pipeline can run.
Without `workflow`, CI steps silently fail to trigger.

### InstantDB — temp app first, then OAuth to make it permanent.

- **Turn 1 (frictionless):** create a temporary app programmatically with
  `instant-cli init-without-files --temp` — no user credentials needed. You
  **MUST** tell the user this is a temporary prototype DB that auto-deletes in 24
  hours, and that making it permanent later requires authorizing the bot.
- **Making it permanent (preferred — OAuth):** prompt the user with a verbatim
  clickable InstantDB OAuth authorization link (redirect URI
  `https://api.prompt2bot.com/oauth-callback`). Once authorized, read the
  permanent `INSTANTDB_TOKEN` from the VM env and run `instant-cli claim` to
  transfer the temp DB into their account, preserving all data.
- **Fallback (manual):** only if OAuth is not used, ask the user to generate an
  App ID + Admin Token from the InstantDB dashboard and paste them.

Do not ask for an InstantDB App ID on turn 1 — start with a temp app.

### Deno Deploy — this is the ONLY credential the user generates manually.

There is no platform OAuth flow for Deno Deploy tokens. Ask the user to generate
a Deno Deploy **organization** token — its value starts with `ddo_`. A personal
token (value starts with `ddp_`) is rejected by the Deno Deploy v2 REST API, so
never request one. Steps to give the user:

1. Sign in at `https://console.deno.com` and create/select an organization first
   (token pages return `404 ORGANIZATION_NOT_FOUND` without one).
2. Open that **organization's** page → **Settings** → **Organization Tokens**,
   and generate the token there. The correct token page lives under the
   organization, never under a personal/account area.
3. Do not output any direct token URL (404s without an org context) or any
   deprecated Deno URL (e.g. `dash.deno.com`). When the user pastes a token,
   confirm it begins with `ddo_`; if it begins with `ddp_`, tell them it is a
   personal token and ask for an organization token via
   Settings → Organization Tokens instead.

Do not ask the user for their Deno Deploy **organization** name — derive it from
the token (the `p2b-deno-deploy` skill covers this). The only thing the user
supplies for Deno Deploy is the token.

## First-turn sequencing

1. Load the coder skill (already done if you are reading this) and this playbook.
2. Call `list_env_variables` to see what credentials already exist.
3. For a working prototype immediately, create the InstantDB temp app
   (`init-without-files --temp`) and tell the user it is temporary.
4. Acquire GitHub access via OAuth (`create_oauth_callback`) — never a PAT.
5. Acquire the Deno Deploy token via the manual console flow above.
6. Batch your asks: send the GitHub OAuth link and the Deno-token instructions
   together so the user has one clear set of steps, not a wall of manual
   token-generation instructions.

Never write code to the ephemeral VM and run it as a "shortcut" before GitHub +
Deno Deploy are set up — the VM expires and the user's work is lost. Set up
permanent hosting (Git + CI/CD) first.

See `vm-and-secrets.md` for the full secret-handling and VM decision matrix, and
`instantdb-guidelines.md` for the full InstantDB progression.
