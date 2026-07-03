# Deno Deploy — Common Mistakes

A checklist of real, observed failures when deploying to Deno Deploy from a
prompt2bot VM. Each entry is a symptom you can recognize, the reason it happens,
and the correct action. Scan this before and during any deploy — every item here
has actually burned a real deployment.

## 1. Using `deployctl` (in a command OR a CI workflow)

- **Symptom:** `APIError: The authorization token is not valid` (either "The
  bearer token is invalid" or "You don't have permission to access the project
  '<slug>'") — even though the token is a fresh `ddo_` token that works
  elsewhere. Appears inside a GitHub Actions log running the `denoland/deployctl`
  action (`uses: denoland/deployctl@v1`) or `deno run -A jsr:@deno/deployctl
  deploy ...`. A classic tell: the live site **works** (you deployed it another
  way) but the CI run is **red** on the "Deploy to Deno Deploy" step.
- **Why:** `deployctl` authenticates against the deprecated Deploy Classic
  backend, which rejects new-console `ddo_` tokens. The token is fine; the CLI
  is wrong. This is the most common way a generated CI workflow ships red,
  because `denoland/deployctl@v1` is the "obvious" action from general knowledge.
- **Fix:** Do NOT write `uses: denoland/deployctl@...` in a workflow. Use the
  canonical workflow from `SKILL.md` ("Deployments are CI-only"), which runs
  `deno run -A --minimum-dependency-age=0 jsr:@deno/deploy@<pin> --app=<slug>
  --org=<org> --prod` with `DENO_DEPLOY_TOKEN` as an `env:` var. Seeing this
  error means "switch CLI/action", not "fix the token", and not "set the token
  as an `with: token:` input" (deployctl ignores that too). Never install, run,
  or reference `deployctl` anywhere — VM shell, scripts, or CI YAML.

## 2. Reporting a `*.deno.dev` URL

- **Symptom:** You tell the user the app is live at
  `https://<app>.deno.dev`, and it 404s.
- **Why:** `*.deno.dev` is the legacy Deploy Classic scheme. The current
  platform serves apps at `https://<app-slug>.<org-slug>.deno.net` — the org
  slug is a required part of the hostname.
- **Fix:** Build the URL as `https://<app>.<org>.deno.net`, take it from the
  deploy output when possible, and verify it loads
  (`curl -sI https://<app>.<org>.deno.net` returns `200`) before telling the
  user it is live. Never guess.

## 3. Running `deno deploy` subcommands before the app exists (VM hang)

- **Symptom:** A `deno deploy` command (even `env list` or `logs`) runs forever
  at ~99% CPU and never returns; you end up killing the process with
  `kill -9`. In CI it shows as a job stuck "in progress" for many minutes.
- **Why:** On a headless, non-TTY VM the CLI blocks waiting for interactive
  input it can never receive (unresolved app/org, or an auth prompt).
- **Fix:** Create the app non-interactively FIRST, with stdin closed and every
  required flag supplied (`--source`, `--region`):
  `deno deploy create --app=<slug> --org=<org> --source local --region global < /dev/null`.
  Only then run `deno deploy --app=<slug> --prod`, `env`, or `logs`. Always wrap
  VM deploy commands with a timeout and closed stdin, e.g.
  `timeout 120 deno deploy ... < /dev/null`. (There is no `--non-interactive`
  flag — closed stdin + complete flags is what prevents the prompt.)

## 4. Polling a possibly-hung deploy in a tight loop

- **Symptom:** Dozens of `check_vm_progress` calls (or `ps aux | grep deno`)
  while a deploy "keeps running", producing no new information.
- **Why:** The command is almost certainly in the interactive loop from #3.
  Polling it harder does not unblock it and wastes turns/tokens.
- **Fix:** If a `deno deploy` command has not returned promptly, treat it as
  hung: stop it, apply the create-first + timeout pattern (#3), and diagnose.
  Do not spawn more polls.

## 5. Pushing speculative deploy "fixes" to trigger CI repeatedly

- **Symptom:** A pile-up of GitHub Actions runs (several `in_progress` at once),
  each triggered by a new commit trying a different deploy config; combined with
  #3 this leaves multiple long-running Actions.
- **Why:** Every push to `main` triggers the deploy workflow. Using pushes as a
  trial-and-error loop multiplies runs and cost.
- **Fix:** Validate the exact `deno deploy` invocation and the app/org slugs
  once (on the VM, non-interactively) before wiring CI. Then push a single,
  verified configuration. Give the CI deploy job a `timeout-minutes` so a
  looping deploy cannot run indefinitely.

## 6. Mixing `--source local` and `--source github`

- **Symptom:** VM-side `deno deploy --app=...` returns "app not found", or your
  uploaded code is ignored while the dashboard builds a different commit.
- **Why:** With `--source github` the dashboard owns the build pipeline; with
  `--source local` your VM/CI owns it. The two paths do not mix on one app.
- **Fix:** Use `--source local` and create apps from the CLI. If the user
  already made a GitHub-integrated app, follow the recovery steps in the main
  skill (check for state, then disconnect the repo or recreate empty via CLI).

## 7. Guessing org/app slugs

- **Symptom:** Commands target the wrong app/org, or you invent a slug that
  doesn't exist.
- **Why:** The CLI has no `list` subcommand, so slugs get guessed.
- **Fix:** Before the first deploy (or anytime unsure), discover slugs via the
  `orgs.list` / `apps.list` tRPC endpoints (see the main skill), then use the
  exact values.

## 8. Wrong token: personal (`ddp_`) instead of organization (`ddo_`)

- **Symptom:** Token starts with `ddp_`, or the v2 REST tools fail with
  `INVALID_TOKEN`, or the user hits `404 ORGANIZATION_NOT_FOUND` on token pages.
- **Why:** The agent sent the user to the **personal** "Account Settings →
  Access Tokens" page, which produces a `ddp_` personal token — the v2 REST API
  rejects it. Or the token came from the deprecated dashboard, or the user has no
  organization yet.
- **Fix:** Require an **organization** token (`ddo_`). Have the user create/pick
  an org at `https://console.deno.com`, then **inside the org** go to
  **Settings → Organization Tokens**. Never point them at the personal Account
  Settings token page. If a pasted token starts with `ddp_`, ask for a `ddo_`
  org token instead.

## 9. Treating a VM-only deploy as permanent

- **Symptom:** A `deno deploy --prod` run straight from the VM "works", but the
  deployment vanishes later.
- **Why:** VMs are ephemeral and get destroyed; a deploy tied only to the VM's
  lifecycle does not persist.
- **Fix:** Deploy through CI (GitHub Actions) so the pipeline lives in the repo.
  Use the VM only to author/validate; let CI own production deploys.

## 10. CI deploys to an app that was never created ("app not found")

- **Symptom:** The CI deploy step fails with
  `The requested app was not found, or you do not have access to view it`
  (exit code 4, NOT_FOUND) on a brand-new project. The agent then wastes turns
  suspecting `DENO_DEPLOY_TOKEN` is invalid or lacks permissions.
- **Why:** A fresh project has no app yet. `deno deploy --app=<slug> --prod`
  does NOT auto-create the app; it deploys to an existing one. With no app (or a
  wrong `--org`), the API reports not-found. This is not a token problem — the
  same token works for `whoami`, `orgs list`, and app creation.
- **Fix:** Make CI create the app idempotently before deploying. Add an
  "Ensure app exists" step that runs
  `deno deploy create --app=<slug> --org=<org> --source local --region global --json < /dev/null || true`
  (CONFLICT / exit 5 means it already exists — ignore it), then the deploy step.
  Always pass BOTH `--app` and `--org` plus the required `--source`/`--region`;
  omitting `--org` also triggers NOT_FOUND. See the canonical workflow in the
  main skill.

## 11. Passing the build-output dir as a positional (`deno deploy out ...`)

- **Symptom:** For a static/framework site (Next.js export, Vite), CI runs
  `deno deploy create out --app=<slug> --org=<org> ...` and/or
  `deno deploy out --app=<slug> --org=<org> --prod ...`. The build "succeeds"
  but the deploy fails with a generic `The revision failed` (or `app not found`,
  exit 4). The agent then loops: delete the app, push an empty commit, retry —
  for many minutes, without ever telling the user.
- **Why:** `deno deploy` has NO positional for the output directory. The bare
  word `out` is parsed as the `[root-path]`, so the app is created/deployed with
  the wrong serving configuration. There is nothing to "retry" — the command
  shape is wrong.
- **Fix:** The static/framework serving config is set on the app at **create**
  time, not passed to `deploy`. On the "Ensure app exists" step use
  `deno deploy create --app=<slug> --org=<org> --source local --runtime-mode static --static-dir <out|dist> --region global --json < /dev/null || true`
  (or `--framework-preset <preset>` for a build-step framework). Keep the deploy
  step a plain
  `deno deploy --app=<slug> --org=<org> --prod < /dev/null`
  with **no positional**. Confirm flags with `deno deploy create --help`. See
  the "Static sites and frameworks" section in the main skill.

## 12. `--non-interactive` on the OLD CLI, or inventing `deno deploy env set`

- **Symptom:** `readdir '--non-interactive'` (os error 2) from a `deno deploy`
  command on an old VM, or `Unknown command "set". Did you mean "list"?` from
  `deno deploy env set KEY=VALUE`. Also `No procedure found on path
  "apps.setEnvVariables"` when trying to set env vars via a tRPC call.
- **Why:** Version-dependent. On the **old CLI (v0.0.99)** `--non-interactive`
  does not exist and is misparsed as a positional `[root-path]`. On the
  **modern CLI (≥ 0.0.9901)** `--non-interactive` is valid and you SHOULD pass
  it (non-interactive `create`/`deploy` needs no extra authorization flag —
  `--apply` is only for the unrelated `setup-cloud` AWS/GCP subcommands, NOT for
  `create`/`--prod`; passing it to `create` errors with `readdir '--apply'`).
  VMs run the base-image shim (≥ 0.0.9903); CI's stock deno resolves the
  built-in to the hanging 0.0.9901, so pin the fixed CLI explicitly there
  (`deno run -A --minimum-dependency-age=0 jsr:@deno/deploy@0.0.9903`, see #14).
  Regardless of version, `env` has no `set`
  subcommand and does not accept `KEY=VALUE`, and there is no
  `apps.setEnvVariables` tRPC procedure.
- **Fix:**
  - Prefer the VM-less `setDenoDeployEnvVar` / `getDenoDeployApp` safescript tools
    (or REST `PATCH/GET https://api.deno.com/v2/apps/<slug>`) — no CLI, no hang.
  - Check the CLI version (`deno deploy --help` / the printed option list is
    authoritative). Modern CLI: pass `--non-interactive`. Old CLI:
    "non-interactive" = close stdin (`< /dev/null`) + every required flag.
  - CLI env subcommands take space-separated args (not `KEY=VALUE`): `add <var>
    <value>`, `list`/`ls`, `update-value`, `delete`/`rm`, `load <file>`. No `set`.
  - `deno deploy create` requires `--source` (`local`) and `--region`
    (`us`|`eu`|`global`) in addition to `--app`/`--org`.

## 13. `deno deploy env` hangs forever on a VM (and `< /dev/null` does NOT fix it)

- **Symptom:** `deno deploy env list`/`env add` on a VM never returns — no
  output, `check_vm_progress` shows "Still running" indefinitely; you end up
  `pkill`-ing deno and resetting the VM. Adding `< /dev/null` does not help.
- **Why:** `env` makes a streaming tRPC call to `console.deno.com` and the CLI
  has **no client-side request timeout**; on some backend states the stream never
  terminates, so it blocks forever. This is a network stall, not a stdin prompt,
  so `< /dev/null` cannot break it. (`create`/`whoami` use other procedures that
  do return.)
- **Fix:** Use the VM-less `setDenoDeployEnvVar` / `getDenoDeployApp` safescript
  tools, or REST `GET/PATCH https://api.deno.com/v2/apps/<slug>` with
  `Authorization: Bearer $DENO_DEPLOY_TOKEN` (both return instantly). If you must
  use any `deno deploy` command on a VM, ALWAYS wrap it: `timeout 120 deno deploy
  … < /dev/null`, so a stall is bounded instead of hanging the VM.

## 14. CI deploy goes red though the site is live (`deno deploy --prod` never exits)

- **Symptom:** The CI Deploy step prints `✔ Successfully uploaded` /
  `✔ Successfully deployed your application!` with the live URL, the site is
  reachable (HTTP 200) — but the step keeps printing the `0/N files uploaded`
  spinner for minutes afterward until the job hits `timeout-minutes` and GitHub
  reports `The operation was canceled`. The build is red despite a successful
  deploy.
- **Why:** A confirmed bug in `@deno/deploy@0.0.9901` (reproduced locally on deno
  2.9.1 and in CI). After a successful deploy the 9901 success path never calls
  `Deno.exit(0)` and leaks open handles (an `EventSource`/tRPC subscription + a
  progress-bar timer), so the process stays alive forever. The failure path DOES
  `Deno.exit(1)`; only success hangs. **`--no-wait` does NOT fix it** — the
  upload path leaks too (verified). The trap: the `deno` binary PINS its built-in
  `deno deploy` to a specific CLI version (deno 2.9.1 → 0.0.9901), so a stock
  `denoland/setup-deno` in CI silently gets the hanging CLI.
- **Fix:** Use `@deno/deploy@0.0.9903`, which calls `Deno.exit(0)` after a
  successful deploy (verified in the JSR source and by running it). A plain
  `deno deploy` resolves the newest version that has cleared deno's supply-chain
  cooldown (`--minimum-dependency-age`), and for now that is the hanging 0.0.9901
  (9902/9903 are too recent to have aged in). So invoke the fixed CLI EXPLICITLY:
  `deno run -A --minimum-dependency-age=0 jsr:@deno/deploy@0.0.9903 --app --org
  --prod --non-interactive`. The `--minimum-dependency-age=0` is required to
  bypass the cooldown so deno will resolve the freshly-published 9903 at all
  (otherwise `newer than the specified minimum dependency date`). Then key
  success off the normal exit code (no marker grep needed); keep `timeout` +
  `timeout-minutes` only as insurance. Never emit a bare `run: deno deploy …
  --prod` as the CI Deploy step — that runs the cooldown-resolved 0.0.9901 and
  hangs. On VMs the base image already shims `deno deploy` to 9903, so a bare
  `deno deploy` there is fine; the explicit `deno run` pin is specifically for
  CI's stock deno. NOTE: once 9903+ ages past the cooldown, a plain `deno deploy`
  will resolve a fixed CLI on its own and this explicit pin can be simplified.
  See `SKILL.md` → "The canonical workflow".

## 15. `invalidToken` from `curl` to a NON-v2 REST path (token is fine)

- **Symptom:** `curl` to `api.deno.com` returns
  `{"code":"invalidToken","message":"The authorization token is not valid: The
  bearer token is invalid."}` — even with a correct `ddo_` token that works with
  the CLI. Leads the agent to (wrongly) tell the user to regenerate the token.
- **Why:** The call hit the **deprecated pre-v2 API** (e.g.
  `https://api.deno.com/organizations`, or `/v1/...`), which does not accept
  new-console `ddo_` tokens. Note the error `code` is camelCase `invalidToken`
  here, vs. the v2 API's `INVALID_TOKEN` (HTTP 401) for a genuinely bad token —
  the casing tells you which API you reached.
- **Fix:** Always use the **`/v2/` path**: `https://api.deno.com/v2/apps`,
  `/v2/apps/<slug>`, etc., with `Authorization: Bearer $DENO_DEPLOY_TOKEN`. A
  `ddo_` token works with both the CLI and REST v2, so `invalidToken` on a raw
  curl means wrong path, not a bad token. Prefer the VM-less safescript tools,
  which target `/v2/` correctly. Do not tell the user to regenerate a `ddo_`
  token on the basis of a non-v2 curl failure.

## 16. Next.js `next build` fails on Deno's builder AFTER a clean upload

- **Symptom:** The deploy CLI prints `✔ Successfully uploaded` and a build URL,
  then `✗ The revision failed`. The build log (`GET
  https://api.deno.com/v2/revisions/<id>/build_logs`) shows one of:
  (a) `✓ Compiled successfully` → `Linting and checking validity of types ...`
  → `Cannot read properties of undefined (reading 'bold')`; (b)
  `TypeError: <x>.useQuery is not a function` / `Error occurred prerendering
  page "/"`; or (c) `module is not defined` while loading `next.config.js`.
  The agent wrongly suspects the token, the CLI hang, or an approval gate —
  none of which are involved; the upload already succeeded.
- **Why:** These are Next-on-Deno build-time bugs, independent of Deploy auth/CLI.
  (a) `next build`'s type-check/lint pass crashes under Deno
  (vercel/next.js#72591). (b) Next 14 App Router prerenders `"use client"` pages
  at build time, so a client-only data hook (InstantDB `useQuery`, any
  WebSocket/browser API) throws during prerender. (c) Deno loads a bare
  `next.config.js` as ESM, so `module.exports` is undefined.
- **Fix:** Configure for all three before the first deploy (see build-config.md
  §6): use `next.config.mjs` with `export default`; set
  `typescript.ignoreBuildErrors` + `eslint.ignoreDuringBuilds`; and keep
  client-only hooks out of prerender by gating the data component behind a
  client-mount check. To diagnose any failed revision, always pull
  `/v2/revisions/<id>/build_logs` — the CLI output alone won't show the real
  cause.

## 17. Hono `serveStatic` imported from the wrong path (build/check fails)

- **Symptom:** `deno check`/deploy fails with `Unknown export './middleware'
  for '@hono/hono@<v>'` (or a similar unknown-export error) from
  `import { serveStatic } from "hono/middleware"`.
- **Why:** On the JSR/Deno build of Hono there is no `hono/middleware` export;
  the Deno static-file middleware lives in the Deno-specific entry.
- **Fix:** Import from `hono/deno`:
  `import { serveStatic } from "hono/deno";`. Run `deno check` locally on the VM
  before deploying so import-path errors surface at build time, not mid-deploy.
