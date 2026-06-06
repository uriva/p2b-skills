---
name: gmail
description: AI agent skill for reading, writing, drafting, and sending emails via Gmail using Safescript.
---

# Gmail Skill

Allows bot to interact with the Gmail API to send emails and create drafts securely, with automatic RFC 1342 encoding of non-ASCII characters (e.g. Hebrew) in headers to prevent garbled text/mojibake.

Pass the configured secret name as `googleToken` when calling tools. Do not pass env var names (for example `GOOGLE_TOKEN`) as the token value.

All functions return `{ success, result, error }`.

## Example usage

```typescript
import { sendGmailEmail } from "./scripts/gmail.ss";
import { createGmailDraft } from "./scripts/gmail.ss";

export const myTask = async () => {
  // Send email safely (subject line non-ASCII characters automatically encoded cleanly)
  const sendRes = await sendGmailEmail(
    "GOOGLE_ACCESS_TOKEN", 
    "recipient@example.com", 
    "הצעה להופעה אקוסטית של שיר אלוני - עדה'ס", 
    "<h1>היי!</h1><p>זהו גוף המייל.</p>"
  );
};
```

---

## Gmail Functions

### sendGmailEmail(googleToken, to, subject, htmlBody)
Sends an HTML email directly through the Gmail API, properly encoding non-ASCII subject lines to avoid mojibake/garbled text.
- `googleToken`: Name of the Gmail OAuth token secret.
- `to`: Recipient email address.
- `subject`: Email subject (automatically encoded to ASCII using UTF-8 Base64 RFC 1342).
- `htmlBody`: HTML content of the email body.

### createGmailDraft(googleToken, to, subject, htmlBody)
Creates an email draft in the user's Gmail account, properly encoding non-ASCII subject lines to avoid mojibake/garbled text.
- `googleToken`: Name of the Gmail OAuth token secret.
- `to`: Recipient email address.
- `subject`: Email subject (automatically encoded to ASCII using UTF-8 Base64 RFC 1342).
- `htmlBody`: HTML content of the email body.
