# Web-App Build & Deploy Playbook

Read this **before doing anything** when the user asks you to build and/or deploy
a web app, dashboard, site, or any hosted service (GitHub repo + CI/CD + permanent
hosting). It defines how to acquire credentials and how to sequence the first
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

### Hosting & Deployment Credentials

When deploying to a cloud hosting platform, identify what credentials or API tokens are needed for automated deployment.
1. Check `list_env_variables` first to see if deployment credentials are already stored.
2. If credentials are required, guide the user with clear, concise instructions on where to generate them in their hosting provider's dashboard or settings.
3. Once provided, store them immediately using `set_secret` and configure them as repository secrets via `gh secret set` for automated CI/CD workflows. Never hardcode credentials in code or repository files.

## First-turn sequencing

1. Load the coder skill (already done if you are reading this) and this playbook.
2. Call `list_env_variables` to see what credentials already exist.
3. Acquire GitHub access via OAuth (`create_oauth_callback`) — never a PAT.
4. Acquire any required hosting deployment credentials.
5. Batch your asks: send the GitHub OAuth link and any deployment credential instructions
   together so the user has one clear set of steps, not a wall of manual instructions.

Never write code to the ephemeral VM and run it as a "shortcut" before GitHub +
hosting are set up — the VM expires and the user's work is lost. Set up
permanent hosting (Git + CI/CD) first.

See `vm-and-secrets.md` for the full secret-handling and VM decision matrix.
