---
name: gmail
description: AI agent skill for sending and drafting emails via Gmail.
---

# Gmail Skill

Allows the bot to interact with the Gmail API to send emails and create drafts securely, with automatic RFC 1342 encoding of non-ASCII characters (e.g. Hebrew) in headers to prevent garbled text/mojibake.

## Important Usage Rules

- **Direct Callable Tools:** `sendGmailEmail` and `createGmailDraft` are exposed directly as callable tools. Call them directly as tools (or via `run_command` with `"gmail/sendGmailEmail"` / `"gmail/createGmailDraft"`). **Never** write `import { ... } from "./scripts/gmail.ss"` inside `run_safescript`.
- **Secret Prefix:** Pass the configured secret name with the `SECRET:` prefix as `googleToken` (for example `"SECRET:GMAIL_ACCESS_TOKEN"` or `"SECRET:GOOGLE_ACCESS_TOKEN"`). Use `list_env_variables` from `secrets_and_variables` if you need to check which secret name is configured.
- **Reading / Searching Emails (Inbox):** This skill is for sending and drafting emails (`gmail.send` scope). To read, list, or search incoming Gmail messages in the user's inbox, use the `composio` skill (`list_composio_tools` with `app: "gmail"`, `inspect_composio_tool`, and `execute_composio_tool` with `GMAIL_FETCH_EMAILS` or `GMAIL_FETCH_MESSAGE_BY_MESSAGE_ID`).

All functions return `{ success, result, error }`.

## Example Tool Call

```json
{
  "googleToken": "SECRET:GMAIL_ACCESS_TOKEN",
  "to": "recipient@example.com",
  "subject": "הצעה להופעה אקוסטית",
  "htmlBody": "<h1>היי!</h1><p>זהו גוף המייל.</p>"
}
```

---

## Gmail Functions

### sendGmailEmail(googleToken, to, subject, htmlBody)
Sends an HTML email directly through the Gmail API, properly encoding non-ASCII subject lines to avoid mojibake/garbled text.
- `googleToken`: Secret reference for the Gmail OAuth token (e.g. `"SECRET:GMAIL_ACCESS_TOKEN"`).
- `to`: Recipient email address.
- `subject`: Email subject (automatically encoded to ASCII using UTF-8 Base64 RFC 1342).
- `htmlBody`: HTML content of the email body.

### createGmailDraft(googleToken, to, subject, htmlBody)
Creates an email draft in the user's Gmail account, properly encoding non-ASCII subject lines to avoid mojibake/garbled text.
- `googleToken`: Secret reference for the Gmail OAuth token (e.g. `"SECRET:GMAIL_ACCESS_TOKEN"`).
- `to`: Recipient email address.
- `subject`: Email subject (automatically encoded to ASCII using UTF-8 Base64 RFC 1342).
- `htmlBody`: HTML content of the email body.
