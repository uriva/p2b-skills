---
name: p2b-deno-deploy
description: Deno Deploy guidance for prompt2bot agents — CLI usage, environment variables, CI deployment, relay server fallbacks, and logging.
---

# p2b-deno-deploy

Deno Deploy skill for prompt2bot agents. Covers deploying, managing environment
variables, CI setup, and relay/backend server patterns.

## Reference files

- `common-mistakes.md`: A scannable checklist of real, observed deploy failures
  (wrong CLI, wrong URL scheme, VM/CI hangs, slug guessing, ephemeral deploys)
  with symptom → cause → fix. **Load and skim it before any deploy**, and
  re-check it whenever a deploy misbehaves — most deploy incidents are one of
  these. Use whichever mechanism your runtime exposes for reading a skill's
  reference file.

## Instructions

### CLI: `deno deploy` (NOT `deployctl`)

**The command is `deno deploy`, a built-in subcommand of the `deno` binary.
NEVER use `deployctl`** — it is deprecated and will not work. Do not
install it (`deno install jsr:@deno/deployctl`), do not run it, do not fall
back to it, and **do not put it in a GitHub Actions workflow** (no
`deno run -A jsr:@deno/deployctl deploy ...` step). This prohibition applies
everywhere — VM shell, scripts, and CI YAML alike. If `deno deploy` fails,
report the exact command and full stderr — do not try `deployctl` as an
alternative.

Why it fails in practice: `deployctl` authenticates against the deprecated
Deploy Classic backend, so a valid new-console `ddo_` token is rejected with
`APIError: The authorization token is not valid: The bearer token is invalid` —
even though the same token works with `deno deploy` and the `api.deno.com/v2`
REST API. Seeing that error means you are on the wrong CLI; switch to
`deno deploy`, do not try to "fix" the token.

The VM is pre-configured with `DENO_DEPLOY_TOKEN` in the environment, so
`deno deploy` authenticates automatically.

**Mandatory safety rule to prevent VM hangs:** Always verify that the `DENO_DEPLOY_TOKEN` environment variable is present (non-empty) in your VM shell before running any `deno deploy` commands (e.g., by running `echo $DENO_DEPLOY_TOKEN` or checking environment variables). If the token is missing, do NOT run any `deno deploy` subcommands (including `whoami`, `orgs list`, or `create`), as they will attempt to run interactively and hang the VM indefinitely. Instead, immediately ask the user to provide their Deno Deploy access token in the chat first!

Deploys and app creation run in CI (see "Deployments are CI-only" below), not
on the VM. The commands below are the building blocks CI uses; `env`/`logs` may
also be run from the VM for inspection. Always pass `--non-interactive` and
redirect `< /dev/null` so nothing ever prompts and hangs:

```bash
deno deploy --app=<slug> --org=<org> --prod --non-interactive < /dev/null   # Deploy
deno deploy create --app=<slug> --org=<org> --non-interactive < /dev/null   # Create app
deno deploy env set KEY=VALUE --app=<slug> --org=<org>                       # Set env vars
deno deploy env list --app=<slug> --org=<org>                               # List env vars
deno deploy logs --app=<slug> --org=<org>                                   # Tail logs
```

Use `deno deploy env set` for Deno Deploy environment variables. Do not ask the
user to set env vars in the dashboard when the CLI can do it; set them yourself
with `deno deploy env set KEY=VALUE ...`, then verify with `deno deploy env
list`.

### Deployed URL format — `<app>.<org>.deno.net` (NOT `.deno.dev`)

The live URL of a deployed app is:

```
https://<app-slug>.<org-slug>.deno.net
```

For example, app `uri-tasks-dashboard` in org `prompt2bot-test` is served at
`https://uri-tasks-dashboard.prompt2bot-test.deno.net`.

**Never construct or report a `*.deno.dev` URL** — that is the legacy Deno
Deploy Classic scheme and will 404 on the current platform. The org slug is a
required part of the hostname; a URL without it is wrong.

Do not guess the URL. Confirm it from the deploy output or the app's config,
which report the real production domain. If you need to derive it, you must know
both the app slug and the org slug (discover the org via `orgs.list`, see
below). Always verify the deployed site actually loads (e.g.
`curl -sI https://<app>.<org>.deno.net` returns `200`) before telling the user
it is live.

**App creation happens in CI, not on the VM** (see "Deployments are CI-only"
below). **Never use the dashboard's "+ New app" or GitHub-integration flow.**
The only things the user does in the Deno dashboard are: create their account,
generate a `ddo_` token, and (optionally) tell you their org slug. Everything
else — creating the app, setting env vars, deploying, viewing logs — is
automated: app creation and deploys via the CI workflow, env vars and logs via
`deno deploy env`/`deno deploy logs` (which may run from the VM for
inspection, but MUST use `--non-interactive < /dev/null`).

Never use `--source github` (the dashboard would own the build pipeline and
watch specific commits, conflicting with CLI deploys). The CI workflow uploads
the checked-out code directly. The two paths do not mix.

**Recovery — user already created an app via the dashboard GitHub flow:**
Signs: the user is looking at an Entrypoint / Edit App Config screen, a Retry
Build button, or Build Triggers showing GitHub commits.

First, check whether the app holds any state:

```bash
deno deploy env list --org <org> --app <slug>      # any env vars?
deno deploy database list --org <org>              # any database linked?
# Also check the dashboard for successful prior revisions.
```

- **If the app is empty** (no env vars, no linked database, no successful prior
  deploys, no real traffic), delete it and recreate via CLI:

  ```bash
  curl -X DELETE -H "Authorization: Bearer $DENO_DEPLOY_TOKEN" \
    https://api.deno.com/v2/apps/<slug>
  # then let the CI workflow recreate + deploy it (see "Deployments are
  # CI-only" — the "Ensure app exists" step recreates it on the next push).
  ```

- **If the app has state** (env vars set, database linked, prior successful
  deploys, or any user traffic), do NOT delete it. Ask the user to disconnect
  the GitHub repo from the app in the dashboard (or remove the Build Trigger),
  then deploy to the same app from the VM with
  `deno deploy --app=<slug> --prod`. This preserves env vars, database links,
  and the URL.

Never delete an app that holds user data or has served traffic without an
explicit confirmation from the user.

`deno deploy --app=<slug> --prod` is the standard way to deploy. It does
diff-sync file upload, tracks the build via SSE (building -> warming ->
routing), and prints the final URL. No entrypoint argument needed if there's a
`deno.json` with a `start` task or a `main.ts` in the project root.

**Do not reimplement Deno Deploy.** Do not write custom scripts that clone the
CLI internals, call hidden tRPC mutations directly, or manually reproduce the
diffsync upload protocol. The correct path is: discover the exact org/app slug,
then run `deno deploy --app=<slug> --prod`. If it fails, report the exact
command and full stderr to the user and stop.

Note: `deno deploy` may create a `deno.jsonc` config file in the project
directory after the first deployment — this is normal.

### Listing apps in an org

The `deno deploy` CLI has no `list` subcommand. To discover which apps exist,
use curl against the tRPC API at `console.deno.com`. The tRPC API authenticates
via cookies, not `Authorization: Bearer`:

```bash
# List orgs
curl -s -H "Cookie: token=$DENO_DEPLOY_TOKEN; deno_auth_ghid=force" \
  "https://console.deno.com/api/orgs.list?batch=1&input=%7B%220%22%3A%7B%7D%7D"

# List apps in an org
curl -s -H "Cookie: token=$DENO_DEPLOY_TOKEN; deno_auth_ghid=force" \
  "https://console.deno.com/api/apps.list?batch=1&input=%7B%220%22%3A%7B%22json%22%3A%7B%22org%22%3A%22ORG_SLUG%22%7D%7D%7D"
```

Replace `ORG_SLUG` with the org slug from the `orgs.list` response.

**Mandatory rule: list before deploy.** Before the **first** deploy attempt
for a project, or anytime you are not 100% certain of the org slug and app
slug, you must run `orgs.list` and then `apps.list`. Do not guess app or org
slugs.

### Deno Deploy tokens

Valid tokens start with `ddo_` (e.g. `ddo_abc123...`). If a user gives you a
token that doesn't start with `ddo_`, it's wrong — likely from the old Deno
dashboard, which is deprecated. The correct place to
create a token is the **new** Deno Deploy console at
**https://console.deno.com**.

**Critical organization requirement:** Deno Deploy console organizes all apps and resources under organizations. If a user has not created an organization on the new console yet, visiting settings or token pages directly will result in a `404 ORGANIZATION_NOT_FOUND` error. Therefore, you **MUST** instruct the user to first sign up/sign in to `https://console.deno.com` and ensure they have created a new organization before generating a token.

Walk the user through the token generation steps:
1. Log in to the main console page at **https://console.deno.com** and ensure an organization is created first.
2. In the dashboard, navigate to your Account Settings -> Access Tokens (doing this via the UI is safe and avoids any direct 404 errors).
3. Create a new token, copy it (it will start with `ddo_`), and paste it here.

This is a common friction point — users often end up on the old deprecated dashboard instead of console.deno.com, paste the wrong value, or hit 404s due to a missing organization.

### v2 REST API

For operations the CLI doesn't support, use the v2 API. The v1 API (`/v1/`) is
deprecated and will not work with `ddo_` tokens.

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

The base path is always `/v2/`. Never call `/v1/`. In v2, "projects" are called
"apps" and "deployments" are called "revisions".

### Deployments are CI-only, and CI creates the app (single canonical path)

There is exactly ONE way to deploy: a GitHub Actions workflow that runs on
push to `main`. Do NOT deploy from the VM, and do NOT create the app from the
VM. Both the app creation and every deploy happen inside CI. This is the whole
deploy model — do not mix it with any VM-side `deno deploy` step.

Why CI-only: the VM is ephemeral (destroyed after ~1h idle, provisioning
churn, or manual delete). Anything deployed or created from the VM vanishes
with it, and the user's live site goes down. CI runs on GitHub's infra, so it
persists regardless of the VM.

Why CI also creates the app: a fresh project has no app yet. If the workflow
jumps straight to `deno deploy --app=<slug> --prod`, Deno returns
**"The requested app was not found, or you do not have access to view it"**
(exit code 4, NOT_FOUND). That error means *the app does not exist yet* (or the
org slug is wrong) — it is NOT a bad token. Do not go debugging
`DENO_DEPLOY_TOKEN`; create the app first. The workflow below does this
idempotently so the very first push and all later pushes both succeed.

**The canonical workflow** (one file, handles first-run creation and all
subsequent deploys):

```yaml
# .github/workflows/deploy.yml
on:
  push:
    branches: [main]
jobs:
  deploy:
    runs-on: ubuntu-latest
    timeout-minutes: 10 # deploy must never run forever
    steps:
      - uses: actions/checkout@v4
      - uses: denoland/setup-deno@v2
        with:
          deno-version: 2.x
      # Create the app if it does not exist yet. --non-interactive fails fast
      # instead of prompting (never hangs). CONFLICT (exit 5) means the app
      # already exists — that is fine, so we swallow a non-zero exit here.
      - name: Ensure app exists
        run: |
          deno deploy create --app=<slug> --org=<org> \
            --non-interactive --json < /dev/null || true
        env:
          DENO_DEPLOY_TOKEN: ${{ secrets.DENO_DEPLOY_TOKEN }}
      - name: Deploy
        run: deno deploy --app=<slug> --org=<org> --prod --non-interactive < /dev/null
        env:
          DENO_DEPLOY_TOKEN: ${{ secrets.DENO_DEPLOY_TOKEN }}
```

Non-negotiable details for CI (they prevent the two failure modes we keep
hitting — hangs and "app not found"):

- **Always pass `--non-interactive` (alias `-y`) and redirect `< /dev/null`**
  on every `deno deploy` subcommand. Without it the CLI may prompt and the
  Action hangs until `timeout-minutes` kills it.
- **Always pass both `--app` and `--org`.** Omitting `--org` is a common cause
  of the NOT_FOUND error even when the app exists.
- **Keep `timeout-minutes: 10`** so a stuck run cannot loop forever.
- Deno's CLI emits stable exit codes: `0` OK, `3` AUTH (bad/missing token),
  `4` NOT_FOUND (app/org wrong), `5` CONFLICT (already exists). Use these to
  reason about failures instead of guessing.

For Next.js or other frameworks, add the framework flags to the `create` step
(e.g. `--framework-preset nextjs`); the `deploy` step stays the same.

For InstantDB, add an `instant-cli push` step to the SAME workflow (before or
after deploy), and set `INSTANTDB_APP_ID` + `INSTANTDB_ADMIN_TOKEN` as repo
secrets.

**Do not treat a push as a way to "try" a deploy fix.** Each push to `main`
triggers this workflow, so pushing repeated speculative fixes piles up deploy
runs. Validate the workflow YAML and the exact app/org slugs once (discover
slugs via the tRPC `orgs.list`/`apps.list` calls above — never guess), then
push a single time and watch that one run.

### Relay/backend servers — fallbacks and logging

When you deploy a relay or backend server on Deno Deploy that needs to call
external APIs (e.g. the prompt2bot API, Make.com, a third-party service), make
it robust against environment-variable misconfiguration:

**Credential fallbacks for stable tokens:** If a token is stable, static, and
specific to the integration (e.g. the bot's own Remote Tools Secret or an API
key that won't rotate often), include a hardcoded fallback directly in the code
alongside the env-var read:

```ts
const P2B_API_TOKEN = Deno.env.get("P2B_API_TOKEN") || "p2b_static_fallback";
```

This decouples the runtime from Deno Deploy env-var configuration errors. If
the env var is missing or invalid, the server still works. If the Deno
deployment token has expired and you cannot use the CLI to repair env vars, the
fallback keeps the integration alive until the token can be refreshed. Always
prefer Deno Deploy env vars first and treat the hardcoded fallback as a safety
net for tokens you manage yourself.

**Default logging for debugging:** Add `console.log` lines for every incoming
request and downstream API response in all deployed relay/backend templates:

```ts
console.log("incoming", method, url);
// ... handler logic ...
console.log("downstream response", status, await response.text().slice(0, 500));
```

This makes live debugging immediate — you can inspect `deno deploy logs` to see
whether webhooks arrived, what the downstream API returned, and where failures
occurred, without needing separate logging infrastructure.

### New Learnings & Best Practices for Deno Deploy & Next.js Defaults

#### 1. Preventing CLI Loops in Headless Sandboxes (VMs)
* **The Issue:** On a headless, non-TTY sandbox VM, **any** `deno deploy`
  subcommand — `--prod`, `env list`, `logs`, `whoami`, etc. — can enter an
  infinite CPU-bound loop (99% CPU) when it needs input it cannot get
  interactively (e.g. the app/org isn't resolved yet, or auth needs a prompt).
  This is a leading cause of hung VMs and, when the same command is placed in a
  workflow, hung GitHub Actions that run for many minutes doing nothing.
* **Hard rules:**
  1. **The app is created FIRST, in CI, before any deploy** — never from the VM
     (see "Deployments are CI-only"). The canonical workflow's "Ensure app
     exists" step handles this idempotently. Deploying to a non-existent app is
     what triggers NOT_FOUND; creating first is what makes deploys
     deterministic.
  2. **Every `deno deploy` invocation — in CI or the occasional VM-side
     `env`/`logs` inspection — MUST pass `--non-interactive` and close stdin
     with `< /dev/null`** so it fails fast instead of looping on a prompt. On a
     VM, also wrap with a hard timeout, e.g.
     `timeout 120 deno deploy env list --app=<slug> --org=<org> --non-interactive < /dev/null`.
     If it hits the timeout, treat it as a real failure to diagnose — do not
     blindly retry.
  3. **Never poll a `deno deploy` command with `check_vm_progress` in a tight
     loop.** If it hasn't returned quickly, it is almost certainly looping; stop
     it and investigate rather than spawning more polls.
* **In CI**, give the deploy job a `timeout-minutes` so a looping deploy cannot
  run for 10+ minutes (see the workflow example above).

#### 2. Exclude Heavy Frontend Development Dependencies from Root `deno.json`
* **The Issue:** Deno Deploy's compiler analyzes all imports defined in the root `deno.json` file. Having heavy, Node-based web development tools (like Vite, PostCSS, Autoprefixer, Tailwind, or complex React components) in your root imports will crash or hang Deno Deploy's compiler during the build phase.
* **The Solution:** 
  1. Compile your frontend locally into pure static assets (`web/dist`).
  2. Isolate frontend-only imports by nesting them in a local `web/deno.json` configuration file, keeping your root `deno.json` imports extremely lightweight and backend-focused (e.g., Hono, Supergreen, Zod).
  3. Declare an explicit `"exclude"` list inside both the `"exclude"` root key and the `"deploy"` key of `deno.json` to prevent Deno Deploy from scanning the frontend source code `/web/src`:
     ```json
     "exclude": ["web"],
     "deploy": {
       "project": "app-name",
       "org": "org-name",
       "entrypoint": "main.ts",
       "exclude": ["node_modules", "web"]
     }
     ```

#### 3. Root Entrypoint (`main.ts`) mapping
* **The Issue:** If your backend entrypoint file is nested inside a subfolder (e.g., `src/server.ts`), Deno Deploy's compiler may fail to automatically locate the primary execution file.
* **The Solution:** Create a 1-line root-level `main.ts` file that simply boots the nested server:
  ```typescript
  import "./src/server.ts";
  ```
  And map `"entrypoint": "main.ts"` inside your `"deploy"` block.

#### 4. Lockfile Synchronization
* **The Issue:** If you modify root dependencies, the `deno.lock` file can fall out of sync, causing Deno Deploy to reject the deployment with strict verification errors.
* **The Solution:** Always run `deno cache <entrypoint>` locally in your workspace to rebuild and synchronize the lockfile prior to pushing.

#### 5. Next.js as the Default Framework for Dynamic Projects
* **Standard Decision:** For all new project architectures that require dynamic content, blog posts, documentation pages, dynamically generated specifications (like `/llms.txt`), dynamic OpenGraph (OG) image generation, or search engine indexing (SEO), **Next.js must be configured as the default framework**.
* **Reasoning:** Next.js provides native Server-Side Rendering (SSR) capabilities. Unlike standard React Single-Page Apps (SPAs) which render as a blank HTML shell requiring client-side JS hydration, Next.js dynamic endpoints deliver fully populated, text-ready HTML directly in the raw response. This ensures 100% readability and immediate indexing by lightweight web crawlers, search engines, and LLM scrappers that cannot execute client-side JavaScript.
