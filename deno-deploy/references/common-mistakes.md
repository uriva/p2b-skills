# Deno Deploy — Common Mistakes

A checklist of real, observed failures when deploying to Deno Deploy from a
prompt2bot VM. Each entry is a symptom you can recognize, the reason it happens,
and the correct action. Scan this before and during any deploy — every item here
has actually burned a real deployment.

## 1. Using `deployctl` (in a command OR a CI workflow)

- **Symptom:** `APIError: The authorization token is not valid: The bearer
  token is invalid` — even though the token is a fresh `ddo_` token that works
  elsewhere. Often appears inside a GitHub Actions log running
  `deno run -A jsr:@deno/deployctl deploy ...`.
- **Why:** `deployctl` authenticates against the deprecated Deploy Classic
  backend, which rejects new-console `ddo_` tokens. The token is fine; the CLI
  is wrong.
- **Fix:** Use `deno deploy` (the built-in subcommand) everywhere — VM shell,
  scripts, and CI YAML. Never install, run, or reference `deployctl`. Seeing
  this error means "switch CLI", not "fix the token".

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
- **Fix:** Create the app non-interactively FIRST, with stdin closed:
  `deno deploy create --app=<slug> --org=<org> --source=local --region=global < /dev/null`.
  Only then run `deno deploy --app=<slug> --prod`, `env`, or `logs`. Always wrap
  VM deploy commands with a timeout and closed stdin, e.g.
  `timeout 120 deno deploy ... < /dev/null`.

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

## 8. Wrong token or missing org

- **Symptom:** Token doesn't start with `ddo_`, or the user hits
  `404 ORGANIZATION_NOT_FOUND` on the settings/token pages.
- **Why:** The token came from the deprecated dashboard, or the user has no
  organization yet on the new console.
- **Fix:** Tokens must be `ddo_...` from `https://console.deno.com`, and the
  user must create an organization there first. Walk them through it if needed.

## 9. Treating a VM-only deploy as permanent

- **Symptom:** A `deno deploy --prod` run straight from the VM "works", but the
  deployment vanishes later.
- **Why:** VMs are ephemeral and get destroyed; a deploy tied only to the VM's
  lifecycle does not persist.
- **Fix:** Deploy through CI (GitHub Actions) so the pipeline lives in the repo.
  Use the VM only to author/validate; let CI own production deploys.
