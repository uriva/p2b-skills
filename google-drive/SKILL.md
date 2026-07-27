---
name: google-drive
description: AI agent skill for interacting with Google Drive.
---

# Google Drive Skill

Allows bot to interact with Google Drive.

All functions require a token parameter that must be mapped to a bot secret via
`secretMapping`. The exact secret name varies per bot. To find the correct name:

1. Call `secrets_and_variables/list_env_variables`
2. Pick the secret whose hosts include `www.googleapis.com` or
   `drive.googleapis.com`
3. Pass that secret name in `secretMapping` (e.g.
   `{ "googleToken": "GOOGLE_WORKSPACE_TOKEN" }`)

Do not guess secret names. Do not pass env var names like `GOOGLE_TOKEN` as
token values. Always discover the name first.

All functions return `{ success, result, error }`.

## Functions

### searchDrive(googleToken, query)
Searches Google Drive for files.
- `query`: A search term (e.g., `"Moving"`) OR a Google Drive API query expression (e.g., `"name contains 'Moving'"`, `"name = 'Moving Log' and mimeType = 'application/vnd.google-apps.spreadsheet'"`). Plain search terms are automatically wrapped in `fullText contains '...' and trashed = false`.

### listFilesByFolder(googleToken, folderId)
Lists non-trashed files inside a Google Drive folder by folder ID (e.g. `"root"`).
