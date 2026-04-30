---
name: google-docs
description: AI agent skill for interacting with Google Docs and Google Sheets.
---

# Google Docs Skill

Allows bot to interact with Google Docs and Google Sheets.

Pass the configured secret name as `googleToken` when calling tools. Do not pass
env var names (for example `GOOGLE_TOKEN`) as the token value.

All functions return `{ success, result, error }`.

For Sheets row-writing tools, pass `row` as a string array.

## Example usage

```typescript
import { createDocument } from "./scripts/google-docs.ss";
import { createSheet } from "./scripts/google-sheets.ss";

export const myTask = async () => {
  const doc = await createDocument(process.env.GOOGLE_TOKEN, "New Doc");
  const sheet = await createSheet(
    process.env.GOOGLE_TOKEN,
    "some-spreadsheet-id",
    "New Sheet",
  );
};
```
