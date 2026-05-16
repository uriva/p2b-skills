---
name: google-docs
description: AI agent skill for interacting with Google Docs and Google Sheets.
---

# Google Docs Skill

Allows bot to interact with Google Docs and Google Sheets.

All functions require a token parameter that must be mapped to a bot secret via
`secretMapping`. The exact secret name varies per bot. To find the correct name:

1. Call `secrets_and_variables/list_env_variables`
2. Pick the secret whose hosts include `www.googleapis.com`,
   `sheets.googleapis.com`, or `docs.googleapis.com`
3. Pass that secret name in `secretMapping` (e.g.
   `{ "googleToken": "GOOGLE_WORKSPACE_TOKEN" }`)

Do not guess secret names. Do not pass env var names like `GOOGLE_TOKEN` as
token values. Always discover the name first.

All functions return `{ success, result, error }`.

For Sheets row-writing tools, pass `row` as a string array.
