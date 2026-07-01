---
name: p2b-deno-deploy
description: Deno Deploy guidance for prompt2bot agents — CLI usage, environment variables, CI deployment, relay server fallbacks, and logging.
---

# p2b-deno-deploy

Deno Deploy skill for prompt2bot agents. Covers deploying, managing environment
variables, CI setup, and relay/backend server patterns.

## Instructions

### CLI: `deno deploy` (NOT `deployctl`)

**The command is `deno deploy`, a built-in subcommand of the `deno` binary.
NEVER use `deployctl`** — it is deprecated and will not work. Do not
install it (`deno install jsr:@deno/deployctl`), do not run it, do not fall
back to it. If `deno deploy` fails, report the error — do not try `deployctl`
as an alternative.

The VM is pre-configured with `DENO_DEPLOY_TOKEN` in the environment, so
`deno deploy` authenticates automatically.

```bash
deno deploy --app=<slug> --prod           # Deploy current directory
deno deploy create <slug>                 # Create an app
deno deploy env set KEY=VALUE ...         # Set environment variables
deno deploy env list                      # List environment variables
deno deploy logs --app=<slug>             # Tail logs
```

Use `deno deploy env set` for Deno Deploy environment variables. Do not ask the
user to set env vars in the dashboard when the CLI can do it; set them yourself
with `deno deploy env set KEY=VALUE ...`, then verify with `deno deploy env
list`.

**Create every app from the VM via CLI. Never use the dashboard's "+ New app"
or GitHub-integration flow.** The only things the user does in the Deno
dashboard are: create their account, generate a `ddo_` token, and (optionally)
tell you their org slug. Everything else — creating apps, setting env vars,
deploying, viewing logs — is done by you from the VM with the `deno deploy`
CLI.

Use `--source local`, never `--source github`. With `--source github`, the
dashboard owns the build pipeline and watches specific commits; your VM-side
`deno deploy --app=...` calls will either return "app not found" or upload code
that the dashboard build ignores. The two paths do not mix.

Standard non-interactive create command:

```bash
deno deploy create \
  --org <org> --app <slug> \
  --source local \
  --runtime-mode dynamic --entrypoint main.ts \
  --build-timeout 5 --build-memory-limit 1024 --region us
```

For Next.js or other frameworks, swap the runtime/entrypoint flags for
`--framework-preset <preset>`.

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
  # then deno deploy create --source local ... as above
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
dashboard (dash.deno.com), which is deprecated. The correct place to
create a token is the **new** Deno Deploy console at
**https://console.deno.com**.

**Critical organization requirement:** Deno Deploy console organizes all apps and resources under organizations. If a user has not created an organization on the new console yet, visiting settings or token pages directly will result in a `404 ORGANIZATION_NOT_FOUND` error. Therefore, you **MUST** instruct the user to first sign up/sign in to `https://console.deno.com` and ensure they have created a new organization before generating a token.

Walk the user through the token generation steps:
1. Log in to **https://console.deno.com** and ensure an organization is created.
2. Go to the account settings / access tokens page at **https://console.deno.com/account/tokens**.
3. Create a new token, copy it (it will start with `ddo_`), and paste it here.

This is a common friction point — users often end up on the old dash.deno.com instead of console.deno.com, paste the wrong value, or hit 404s due to a missing organization.

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

### CI-only for deployments

**Never run `deno deploy` manually on the VM.** The VM is ephemeral — it can
be deleted at any time, which means any manually triggered deployment
disappears with it. Deployments must be done via **CI** (GitHub Actions), not
via direct CLI on the VM.

**Correct pattern:**

1. On the VM, write and test code.
2. Push changes to GitHub (via Contents API or `gh`).
3. Set up a GitHub Actions workflow in the repo that runs
   `deno deploy --app=<slug> --prod` on every push to `main`. The workflow
   runs on GitHub's infrastructure, not the VM, so it persists regardless of
   what happens to the VM.
4. Merging or pushing to `main` triggers the workflow, which deploys.

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

For InstantDB, the same pattern applies — add `instant-cli push` to a workflow
step, and set `INSTANTDB_APP_ID` + `INSTANTDB_ADMIN_TOKEN` as repo secrets.

**Common mistake to avoid:** Running `deno deploy --prod` directly on the VM
to "test the deployment". It works in the moment, but the next time the VM is
recreated (or destroyed), the deployment is gone. Always push to GitHub and let
CI handle it.

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
* **The Issue:** Running `deno deploy` without prior project creation on a headless, non-TTY sandbox VM can cause the Deno Deploy CLI to enter an infinite CPU-bound loop (consuming 99% CPU) while polling for interactive user inputs.
* **The Solution:** Always provision the application explicitly first using the non-interactive `create` command with closed `stdin` (`< /dev/null`):
  ```bash
  deno deploy create --app=<app-slug> --org=<org-slug> --source=local --region=global < /dev/null
  ```
  Once the app is created in Deno Deploy, the deploy command `deno deploy --app=<app-slug> --prod` will run deterministically in the background without any loops.

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
