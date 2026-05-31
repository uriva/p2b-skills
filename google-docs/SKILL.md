---
name: google-docs
description: AI agent skill for interacting with Google Docs and Google Sheets.
---

# Google Docs Skill

Allows bot to interact with Google Docs and Google Sheets.

Pass the configured secret name as `googleToken` when calling tools. Do not pass
env var names (for example `GOOGLE_TOKEN`) as the token value.

All functions return `{ success, result, error }`.

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

---

## Google Sheets Functions

### appendRowToSheet(googleToken, spreadsheetId, range, row)
Appends a single row (array of strings) of values to a sheet at the end of the specified range.

### readSpreadsheet(googleToken, spreadsheetId, range)
Reads and retrieves values from the specified range of a spreadsheet.

### updateRowInSheet(googleToken, spreadsheetId, range, row)
Updates/overwrites a single row (array of strings) of values at the specified range.

### createSheet(googleToken, spreadsheetId, sheetTitle)
Creates a new sheet (tab) with the given title in the spreadsheet.

### insertRows(googleToken, spreadsheetId, sheetId, sheetName, startIndex, numRows, rows)
Safely inserts `numRows` of new blank rows at `startIndex` (0-indexed) in the specified sheet `sheetId`, shifting existing rows down, and then writes the given `rows` values starting at the inserted position.
- `sheetId`: The GID of the sheet tab (e.g. `0`, `1930487212`).
- `sheetName`: The string name of the sheet tab (e.g. `"מעקב הכנסות והוצאות שנתי"`).
- `startIndex`: The 0-indexed row position where the new rows should be inserted.
- `numRows`: The number of rows to insert.
- `rows`: A 2D array of strings representing the cells to populate in the newly created rows (e.g., `[["A1_val", "B1_val"], ["A2_val", "B2_val"]]`).

### formatCells(googleToken, spreadsheetId, sheetId, startRowIndex, endRowIndex, startColumnIndex, endColumnIndex, cell, fields)
Applies formatting and styles to a specified grid range of a sheet using a `repeatCell` batch update.
- `sheetId`: GID of the sheet tab.
- `startRowIndex` / `endRowIndex`: 0-indexed row indices of the range.
- `startColumnIndex` / `endColumnIndex`: 0-indexed column indices of the range.
- `cell`: The cell metadata object containing the styles to apply (e.g., `userEnteredFormat`).
- `fields`: Comma-separated list of paths to update (e.g., `"userEnteredFormat.backgroundColor,userEnteredFormat.textFormat"`).

Example format payload to force plain text formatting:
```json
{
  "cell": {
    "userEnteredFormat": {
      "numberFormat": {
        "type": "TEXT"
      }
    }
  },
  "fields": "userEnteredFormat.numberFormat"
}
```

Example format payload to set background color (pastel red) and bold text:
```json
{
  "cell": {
    "userEnteredFormat": {
      "backgroundColor": {
        "red": 0.98,
        "green": 0.8,
        "blue": 0.8
      },
      "textFormat": {
        "bold": true
      }
    }
  },
  "fields": "userEnteredFormat.backgroundColor,userEnteredFormat.textFormat"
}
```

### batchUpdateSpreadsheet(googleToken, spreadsheetId, requests)
Executes a generic `batchUpdate` containing any list of Google Sheets API requests (such as `insertDimension`, `repeatCell`, `updateSheetProperties`, etc.).
- `requests`: Array of request objects (e.g., `[{ repeatCell: ... }, { updateSheetProperties: ... }]`).
