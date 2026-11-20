---
name: google-docs
description: AI agent skill for reading, editing, and creating Google Docs (with compact outline/section readers and high-level insertion helpers) and Google Sheets.
---

# Google Docs & Sheets Skill

Allows the bot to read, edit, and create Google Docs and Google Sheets directly via Safescript tools.

## Authentication & Secret Selection

- Always check `list_env_variables` first to see which Google OAuth token secret is already stored (for example `GOOGLE_ACCESS_TOKEN`, `GOOGLE_DOCS_TOKEN`, or `GOOGLE_SHEETS_TOKEN` — a Google OAuth token granted both Docs and Sheets scopes works for both APIs).
- Pass the secret reference as `SECRET:<SECRET_NAME>` in the `googleToken` parameter (e.g. `"SECRET:GOOGLE_ACCESS_TOKEN"`). Never pass a bare env var name without `SECRET:`.
- If Composio's `googledocs` integration is disconnected, use the `google-docs` tools below with the bot's stored Google OAuth token secret instead of asking to reconnect Composio.
- All functions return `{ success, result, error }`.
- Call functions directly as tools — never `import` `.ss` files inside `run_safescript`.

---

## Google Docs Functions

**Prefer compact readers and high-level helpers** — avoid `fetchDocument` for normal reading/editing because raw Google Docs JSON can exceed 500 KB of formatting metadata.

### readDocumentOutline(googleToken, documentId) — Recommended Reader
Fetches a compact outline of the document using Google Docs API field projection (headings, paragraphs, bullet items, `nestingLevel`, `listId`, and exact UTF-16 `startIndex`/`endIndex`) without style metadata bloat.

```json
{
  "googleToken": "SECRET:GOOGLE_ACCESS_TOKEN",
  "documentId": "1abc..."
}
```

### readDocumentSection(googleToken, documentId, headingQuery)
Finds the first heading or bullet item matching `headingQuery` (case-insensitive substring) and returns only the items in that section along with `insertAfterHeadingIndex` and `appendAtSectionEndIndex`.

### insertUnderHeading(googleToken, documentId, headingQuery, text, asBullet, position) — Recommended Editor
High-level helper to add an item or paragraph under a matching heading or bullet section without manually computing UTF-16 indices.
- `headingQuery`: Heading or parent bullet text to match (e.g. `"Sci-fi"` or `"Series"`).
- `text`: Plain text to insert (no trailing newline needed).
- `asBullet` (default `true`): When `true`, inherits the section's bullet list/nesting level (or creates a bullet item under a non-bullet heading).
- `position` (default `"bottom"`): `"bottom"` appends at the end of the section; `"top"` inserts immediately after the matched heading.

```json
{
  "googleToken": "SECRET:GOOGLE_ACCESS_TOKEN",
  "documentId": "1abc...",
  "headingQuery": "Sci-fi",
  "text": "Andor",
  "asBullet": true,
  "position": "bottom"
}
```

### insertInlineImage(googleToken, documentId, index, imageUrl, widthPt, heightPt)
Inserts a publicly accessible image (`imageUrl`) at UTF-16 `index` (get the index from `readDocumentOutline` or `readDocumentSection`). Pass `widthPt` / `heightPt` in points (> 0), or `0` to keep default image dimensions.

### batchUpdateDocument(googleToken, documentId, requests) — Typed Batch Update
Executes a Google Docs `:batchUpdate` from a typed array of request objects (automatically wrapped in `{"requests": [...]}`).

```json
{
  "googleToken": "SECRET:GOOGLE_ACCESS_TOKEN",
  "documentId": "1abc...",
  "requests": [
    { "insertText": { "location": { "index": 42 }, "text": "New line\n" } }
  ]
}
```

### createDocument(googleToken, title)
Creates a new empty Google Doc and returns the created document metadata (including `documentId`).

### executeBatchUpdate(googleToken, documentId, requestsBody)
Low-level string-payload wrapper for `:batchUpdate`. Accepts a JSON string `{"requests":[...]}` (or a bare `[...]` JSON array, which is automatically wrapped). Prefer `insertUnderHeading`, `insertInlineImage`, or `batchUpdateDocument`.

### fetchDocument(googleToken, documentId)
Fetches the full raw Google Docs API JSON AST. Only use this when you explicitly need low-level formatting/style metadata not included in `readDocumentOutline`.

---

## Google Sheets Functions

### createSpreadsheet(googleToken, title)
Creates a new Google Spreadsheet with the specified title and returns the new spreadsheet metadata (including `spreadsheetId`).

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
- `sheetName`: The string name of the sheet tab.
- `startIndex`: The 0-indexed row position where the new rows should be inserted.
- `numRows`: The number of rows to insert.
- `rows`: A 2D array of strings representing the cells to populate in the newly created rows.

### formatCells(googleToken, spreadsheetId, sheetId, startRowIndex, endRowIndex, startColumnIndex, endColumnIndex, cell, fields)
Applies formatting and styles to a specified grid range of a sheet using a `repeatCell` batch update.
- `sheetId`: GID of the sheet tab.
- `startRowIndex` / `endRowIndex`: 0-indexed row indices of the range.
- `startColumnIndex` / `endColumnIndex`: 0-indexed column indices of the range.
- `cell`: The cell metadata object containing the styles to apply (e.g., `userEnteredFormat`).
- `fields`: Comma-separated list of paths to update (e.g., `"userEnteredFormat.backgroundColor,userEnteredFormat.textFormat"`).

### batchUpdateSpreadsheet(googleToken, spreadsheetId, requests)
Executes a generic `batchUpdate` containing any list of Google Sheets API requests (such as `insertDimension`, `repeatCell`, `updateSheetProperties`, etc.).
- `requests`: Array of request objects (e.g., `[{ repeatCell: ... }, { updateSheetProperties: ... }]`).
