# Recovery — user already created an app via the dashboard GitHub flow

Read this when the user set up their Deno Deploy app through the dashboard's "+
New app" / GitHub-integration flow instead of the canonical CI workflow. Signs:
the user is looking at an Entrypoint / Edit App Config screen, a Retry Build
button, or Build Triggers showing GitHub commits. The dashboard GitHub
integration owns the build pipeline and watches specific commits, which
conflicts with the CI-driven `deno deploy` path — the two do not mix.

First, check whether the app holds any state:

```bash
deno deploy env list --org <org> --app <slug>      # any env vars?
deno deploy database list --org <org>              # any database linked?
# Also check the dashboard for successful prior revisions.
```

- **If the app is empty** (no env vars, no linked database, no successful prior
  deploys, no real traffic), delete it and let CI recreate it:

  ```bash
  curl -X DELETE -H "Authorization: Bearer $DENO_DEPLOY_TOKEN" \
    https://api.deno.com/v2/apps/<slug>
  # then let the CI workflow recreate + deploy it (see SKILL.md "Deployments are
  # CI-only" — the "Ensure app exists" step recreates it on the next push).
  ```

- **If the app has state** (env vars set, database linked, prior successful
  deploys, or any user traffic), do NOT delete it. Ask the user to disconnect
  the GitHub repo from the app in the dashboard (or remove the Build Trigger),
  then deploy to the same app through the canonical CI workflow (pointing its
  `--app`/`--org` at the existing slug). This preserves env vars, database
  links, and the URL. Do not deploy from the VM.

Never delete an app that holds user data or has served traffic without an
explicit confirmation from the user.
