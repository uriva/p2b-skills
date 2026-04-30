---
name: google-drive
description: AI agent skill for interacting with Google Drive.
---

# Google Drive Skill

Allows bot to interact with Google Drive.

Pass the configured secret name as `googleToken` when calling tools. Do not pass
env var names (for example `GOOGLE_TOKEN`) as the token value.

All functions return `{ success, result, error }`.

## Example usage

```typescript
import { listFilesByFolder, searchDrive } from "./scripts/google-drive.ss";

export const myTask = async () => {
  const files = await listFilesByFolder(
    process.env.GOOGLE_TOKEN,
    "some-folder-id",
  );
  console.log(files);
};
```
