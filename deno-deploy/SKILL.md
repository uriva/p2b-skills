---
name: p2b-deno-deploy
description: Deno Deploy guidance and VM-less safescript tools for prompt2bot agents — REST API v2 app/env-var/revision operations, CLI usage, CI deployment, and logging.
---

# p2b-deno-deploy

Deno Deploy skill for prompt2bot agents. Covers deploying, managing environment
variables, CI setup, and relay/backend server patterns.

## The token: require an `ddo_` ORGANIZATION token (never a personal token)

You need an **organization** access token (starts with `ddo_`). A **personal**
token (starts with `ddp_`) is **rejected by the REST v2 API** (`INVALID_TOKEN`),
so it breaks the VM-less tools below. Always require `ddo_`.

**How the user creates it (exact path):** sign in at `https://console.deno.com`,
select or create an **organization** first (token pages 404 with
`ORGANIZATION_NOT_FOUND` before an org exists), then **inside that organization**
go to **Settings → Organization Tokens** and create the token. Do NOT send them
to the personal **Account Settings → Access Tokens** page — that yields a `ddp_`
token which fails. When a token is pasted, verify it starts with `ddo_`.

If you get `invalidToken: The bearer token is invalid`, it's almost always a
**wrong URL path, not a bad token** — use `https://api.deno.com/v2/...`, never
`api.deno.com/organizations` or `/v1/` (see common-mistakes #15).

## VM-less tools (prefer these for app + env-var operations)

This skill ships safescript tools that call the REST API v2 (`api.deno.com`)
directly — **no VM required**, each with a built-in request timeout so it can
never hang like the `deno deploy` CLI (see "Why the `env` CLI hangs"). Prefer
them for discovering apps, reading/setting env vars, creating an app, and
checking the last deploy's status:

- `listDenoDeployApps` — list apps reachable by the token (discover slugs; never guess).
- `getDenoDeployApp` — get an app's details, including current `env_vars`.
- `createDenoDeployApp` — create an app (org derived from the token; no `--org`).
- `setDenoDeployEnvVar` — add/update one env var (deep-merged by key). Use
  `isSecret: false` for public build-time vars (e.g. `NEXT_PUBLIC_*`), `true` for
  credentials.
- `latestDenoDeployRevision` — latest revision status (`queued`/`building`/`succeeded`/`failed` + `failure_reason`) to check whether a deploy worked.

Each takes `denoDeployToken`; bind it to the stored secret by passing
`"SECRET:DENO_DEPLOY_TOKEN"` (the runtime substitutes the decrypted token). The
secret must list `api.deno.com` in its allowed hosts; a host-policy rejection is
a bot-settings fix (add `api.deno.com`), not a code change.

These do NOT deploy code — a production deploy still runs through CI (see
"Deployments are CI-only"). Use these for everything around the deploy.

## Reference files

- `common-mistakes.md`: Scannable checklist of real deploy failures (wrong CLI,
  wrong URL scheme, VM/CI hangs, slug guessing, ephemeral deploys) with symptom →
  cause → fix. **Load and skim it before any deploy** and re-check whenever a
  deploy misbehaves — most incidents are one of these.
- `build-config.md`: Build/entrypoint config, excluding heavy frontend deps from
  root `deno.json`, lockfile sync, VM CLI-loop prevention, Next.js default-framework
  policy, and **§6 making a Next.js build succeed under Deno** (`.mjs` config, skip
  the crashing type-check/lint, keep client-only hooks out of prerender). **Read
  when setting up a build/entrypoint, using Next.js, or a revision fails** (see #16).

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

Why it fails: `deployctl` uses the deprecated Deploy Classic backend and is
rejected regardless of token. Use `deno deploy` (the built-in subcommand)
instead — a `ddo_` token authenticates it automatically.

The VM has `DENO_DEPLOY_TOKEN` in the environment, so `deno deploy`
authenticates automatically; verify it is present (`echo $DENO_DEPLOY_TOKEN`)
before any CLI call.

Deploys and app creation run in CI (see "Deployments are CI-only" below). For
app/env-var inspection and changes, **prefer the VM-less safescript tools
above** over the CLI. If you do use the CLI on a VM, follow these rules:

The VM base image shims `deno deploy` to ≥ 0.0.9902, which exits cleanly after a
successful deploy and adds `logs --once` (drain current logs then exit). Still
wrap every VM `deno deploy` in `timeout … < /dev/null` as insurance. Pass
`--non-interactive` (fast-fail on missing input) and supply every REQUIRED flag;
non-interactive create/deploy needs no extra authorization flag.

```bash
timeout 300 deno deploy --app=<slug> --org=<org> --prod --non-interactive < /dev/null   # Deploy (exits 0 on success)
timeout 180 deno deploy create --app=<slug> --org=<org> --source local --region global --non-interactive < /dev/null  # Create app
timeout 120 deno deploy logs --app=<slug> --org=<org> --once --non-interactive < /dev/null       # Capture current logs then exit
```

`deno deploy create` REQUIRES `--source local` and `--region` (`us`|`eu`|`global`)
plus `--app`/`--org`. Use `logs --once` (not a bare `logs`, which tails forever)
for a bounded snapshot; widen with `--start`.

**Why the `env` CLI hangs (use the safescript tools / REST instead):**
`deno deploy env list`/`env add` make a **streaming tRPC call** to
`console.deno.com` with **no client-side timeout**. On some backend states that
stream never terminates, so the command hangs indefinitely — and **`< /dev/null`
does NOT fix it** (it is a network stall, not a stdin prompt; two runs with
`< /dev/null` still hung). Do env vars via `setDenoDeployEnvVar` /
`getDenoDeployApp` (or a plain `PATCH`/`GET https://api.deno.com/v2/apps/<slug>`
with `Authorization: Bearer $DENO_DEPLOY_TOKEN`), which return instantly. If you
must use the CLI `env` subcommands (`list`/`ls`, `add <var> <value>` —
space-separated, NOT `KEY=VALUE`; there is no `env set`), always `timeout`-wrap
them. See `common-mistakes.md` (#12).

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
The only thing the user does in the Deno dashboard is create their account and
generate a `ddo_` token. **Do not ask them for their org slug — derive it from
the token** (see "Discovering the org and apps"). Everything
else — creating the app, setting env vars, deploying, viewing logs — is
automated: app creation and deploys via the CI workflow, env vars and logs via
`deno deploy env`/`deno deploy logs` (which may run from the VM for
inspection, but MUST close stdin with `< /dev/null` and pass every required
flag so nothing prompts).

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

### Discovering apps (derive from the token — do NOT ask the user)

**The token already knows which org(s)/apps it can reach.** Never ask the user
for their org name or an app slug, and never send them to the console to read it
— the only thing they must supply is a valid `ddo_` token.

- **Primary: `listDenoDeployApps`** (safescript tool above) — returns the apps
  reachable by the token, with no VM and no hang risk. Use it to confirm/choose
  the app slug.
- CLI alternative (VM, always timeout-wrapped): `timeout 60 deno deploy whoami
  --json < /dev/null` returns the token's `orgs[]` (use an org's `slug` for
  `--org`). Exactly one org → use it silently; multiple → present the real slugs
  and let the user pick; zero / `authenticated:false` → bad token.

**Mandatory rule: discover before deploy.** Before the first deploy for a project
(or whenever unsure of the app slug), confirm the app via `listDenoDeployApps`.
Never guess, and never ask the user for, an org or app slug.

### Deno Deploy tokens

See the top **"The token"** section for the full rule: require a `ddo_`
**organization** token created **inside the org** at **Settings → Organization
Tokens** on `https://console.deno.com`; never the personal Account Settings page
(yields a `ddp_` token the v2 REST API rejects), never the deprecated dashboard.

### v2 REST API (backs the safescript tools)

The VM-less tools call this API; use raw curl only for what they don't cover
(e.g. delete an app). Base path is always `/v2/` (the pre-v2/`/v1/` API rejects
`ddo_` tokens with `invalidToken` — see common-mistakes #15); auth is
`Authorization: Bearer $DENO_DEPLOY_TOKEN`; org is derived from the token.
"projects"→"apps", "deployments"→"revisions".

```bash
# Read app (incl. env_vars):  GET  /v2/apps/<slug>
# Set env var (deep-merge):   PATCH /v2/apps/<slug>  -d '{"env_vars":[{"key":"K","value":"V","secret":false}]}'
# List apps:                  GET  /v2/apps
# Delete an app:              DELETE /v2/apps/<slug>
# Latest deploy status:       GET  /v2/apps/<slug>/revisions?limit=1   (status: queued|building|succeeded|failed)
```

Env var body is an ARRAY of `{key,value,secret}` objects (not `{K:V}` and not
`["K=V"]`). Prefer the `setDenoDeployEnvVar` tool, which encodes this correctly.

### Deployments are CI-only, and CI creates the app (single canonical path)

There is exactly ONE way to deploy: a GitHub Actions workflow on push to
`main`. Do NOT deploy or create the app from the VM — it is ephemeral
(destroyed after ~1h idle/churn/delete), so anything created there vanishes and
the site goes down; CI persists on GitHub's infra. CI also creates the app
(idempotently) because a fresh project has no app yet: deploying to a
non-existent app returns **"The requested app was not found…"** (exit 4,
NOT_FOUND) — a wrong app/org slug or missing app, NOT a bad token, so don't
debug `DENO_DEPLOY_TOKEN`.

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
      # The `deno` binary pins its built-in `deno deploy` to an OLD Deploy CLI
      # (2.9.x -> 0.0.9901) that HANGS after a successful `--prod` deploy. Pin the
      # fixed CLI (>= 0.0.9902: clean exit on success) explicitly via `deno run`
      # so CI does not inherit the stale built-in. `--minimum-dependency-age=0`
      # lets deno resolve a JSR package newer than its own build date. (#14)
      # Create the app if missing. Every required flag + closed stdin means it
      # can't prompt/hang; CONFLICT (exit 5) = already exists, so `|| true`.
      - name: Ensure app exists
        run: |
          deno run -A --minimum-dependency-age=0 jsr:@deno/deploy@0.0.9902 create --app=<slug> --org=<org> \
            --source local --region global --json --non-interactive < /dev/null || true
        env:
          DENO_DEPLOY_TOKEN: ${{ secrets.DENO_DEPLOY_TOKEN }}
      # 0.0.9902 exits 0 after a successful deploy, so key success off the exit
      # code. `timeout` stays as insurance only. Never use the built-in
      # `deno deploy` here (it is 0.0.9901 and hangs after success).
      - name: Deploy
        run: |
          set -euo pipefail
          timeout 300 deno run -A --minimum-dependency-age=0 jsr:@deno/deploy@0.0.9902 --app=<slug> --org=<org> \
            --prod --non-interactive < /dev/null
        env:
          DENO_DEPLOY_TOKEN: ${{ secrets.DENO_DEPLOY_TOKEN }}
```

Non-negotiable details for CI (they prevent hangs and "app not found"):

- **Never call the built-in `deno deploy` in CI.** `denoland/setup-deno` gives a
  stock `deno` whose built-in Deploy CLI is 0.0.9901, which HANGS after a
  successful `--prod` deploy (runs until `timeout-minutes`). Invoke the fixed CLI
  explicitly: `deno run -A --minimum-dependency-age=0 jsr:@deno/deploy@0.0.9902
  …` (the flag lets deno resolve a package newer than its build date). It
  `Deno.exit(0)`s after success, so key success off the exit code (no marker
  grep). See `common-mistakes.md` #14.
- Pass `--non-interactive` (fast-fail) + `< /dev/null` + every required flag
  (`create`: `--source local --region global --app --org`). Keep
  `timeout-minutes: 10` as insurance.
- **Always pass both `--app` and `--org`** — omitting `--org` causes NOT_FOUND
  even when the app exists.
- Exit codes: `0` OK, `3` AUTH, `4` NOT_FOUND, `5` CONFLICT (already exists) —
  reason from these instead of guessing.

#### Static sites and frameworks (Next.js, Vite, etc.) — configure at CREATE time, never as a positional

The single biggest deploy failure we hit is passing the build-output dir as a
**positional** to `deno deploy`. There is NO positional for the output dir:
`deno deploy out ...` / `deno deploy create out ...` misparse `out` as the
`[root-path]`, the app gets the wrong config, and the revision fails
(`The revision failed` / `app not found`, exit 4) — triggering an endless
delete-app → empty-commit → retry loop.

The **serving config lives on the app** (set at create time). So put the
framework/static flags on the **`create` (Ensure app exists)** step, and keep
the **`deploy`** step positional-free (the `timeout`-wrapped step above).

- **Static export** (Next.js `output: "export"` → `out/`, Vite → `dist/`, plain
  static → the built dir):

  ```yaml
  - name: Ensure app exists
    run: |
      deno run -A --minimum-dependency-age=0 jsr:@deno/deploy@0.0.9902 create --app=<slug> --org=<org> \
        --source local --runtime-mode static --static-dir out \
        --region global --json --non-interactive < /dev/null || true
    env:
      DENO_DEPLOY_TOKEN: ${{ secrets.DENO_DEPLOY_TOKEN }}
  ```
  (use `--static-dir dist` for Vite, `--single-page-app` for a client-routed
  SPA). The `deploy` step is unchanged — still the pinned `deno run -A
  jsr:@deno/deploy@0.0.9902 … --prod` step above (never the built-in
  `deno deploy`, which is 0.0.9901 and hangs after success).

- **Framework with a build step** (let Deno detect/run the build):
  add `--framework-preset <preset>` (and optionally `--build-command`) to the
  same `create` step instead of `--runtime-mode static`.

Discover the exact accepted flags with `deno deploy create --help` — the printed
option list is authoritative. A valid static create is:
`deno deploy create --json --org my-org --app my-app --source local --runtime-mode static --static-dir dist --region us < /dev/null`.
See `common-mistakes.md` (#11) for the failure signature.

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

This decouples the runtime from env-var config errors: if the env var is
missing/invalid (or the deploy token expired so you can't repair env vars), the
server still works until the token is refreshed. Prefer env vars first; treat
the fallback as a safety net for tokens you manage yourself.

**Default logging for debugging:** Add `console.log` lines for every incoming
request and downstream API response in all deployed relay/backend templates:

```ts
console.log("incoming", method, url);
// ... handler logic ...
console.log("downstream response", status, await response.text().slice(0, 500));
```

This makes live debugging immediate via `deno deploy logs` (whether webhooks
arrived, what the downstream returned, where it failed) with no extra infra.

### Build configuration & framework defaults

Build/entrypoint config, avoiding Deploy-compiler crashes/hangs on heavy
frontend deps, lockfile sync, VM CLI-loop prevention, and the Next.js
default-framework policy live in `build-config.md`. Read it when setting up a
project's build/entrypoint or choosing a framework for a new dynamic project.
