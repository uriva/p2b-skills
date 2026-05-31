appendRowToSheet = (googleToken: string, spreadsheetId: string, range: string, row: string[]): { success: boolean, result: string, error: string } => {
  encodedRange = urlEncode({ text: range })
  path = stringConcat({ parts: ["/v4/spreadsheets/", spreadsheetId, "/values/", encodedRange.encoded, ":append?valueInputOption=USER_ENTERED"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { values: [row] } })
  res = httpRequest({ host: "sheets.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_SHEETS_API_ERROR: Received non-JSON response. Check token secret name and Sheets scopes." : stringConcat({ parts: ["GOOGLE_SHEETS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

readSpreadsheet = (googleToken: string, spreadsheetId: string, range: string): { success: boolean, result: string, error: string } => {
  encodedRange = urlEncode({ text: range })
  path = stringConcat({ parts: ["/v4/spreadsheets/", spreadsheetId, "/values/", encodedRange.encoded] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "sheets.googleapis.com", method: "GET", path: path.result, headers: { "Authorization": auth.result } })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_SHEETS_API_ERROR: Received non-JSON response. Check token secret name and Sheets scopes." : stringConcat({ parts: ["GOOGLE_SHEETS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

updateRowInSheet = (googleToken: string, spreadsheetId: string, range: string, row: string[]): { success: boolean, result: string, error: string } => {
  encodedRange = urlEncode({ text: range })
  path = stringConcat({ parts: ["/v4/spreadsheets/", spreadsheetId, "/values/", encodedRange.encoded, "?valueInputOption=USER_ENTERED"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { values: [row] } })
  res = httpRequest({ host: "sheets.googleapis.com", method: "PUT", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_SHEETS_API_ERROR: Received non-JSON response. Check token secret name and Sheets scopes." : stringConcat({ parts: ["GOOGLE_SHEETS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

createSheet = (googleToken: string, spreadsheetId: string, sheetTitle: string): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v4/spreadsheets/", spreadsheetId, ":batchUpdate"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { requests: [ { addSheet: { properties: { title: sheetTitle } } } ] } })
  res = httpRequest({ host: "sheets.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_SHEETS_API_ERROR: Received non-JSON response. Check token secret name and Sheets scopes." : stringConcat({ parts: ["GOOGLE_SHEETS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

insertRows = (googleToken: string, spreadsheetId: string, sheetId: number, sheetName: string, startIndex: number, numRows: number, rows: string[][]): { success: boolean, result: string, error: string } => {
  endIndex = startIndex + numRows
  pathBatch = stringConcat({ parts: ["/v4/spreadsheets/", spreadsheetId, ":batchUpdate"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  bodyBatch = jsonStringify({ value: { requests: [ { insertDimension: { range: { sheetId: sheetId, dimension: "ROWS", startIndex: startIndex, endIndex: endIndex }, inheritFromBefore: false } } ] } })
  resBatch = httpRequest({ host: "sheets.googleapis.com", method: "POST", path: pathBatch.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: bodyBatch.text })
  isHtml1 = stringIncludes({ haystack: stringLower({ text: resBatch.body }).result, needle: "<html" })
  isSuccess1 = resBatch.status == 200 ? true : false
  errorBody1 = isHtml1.result ? "GOOGLE_SHEETS_API_ERROR: Received non-JSON response from batchUpdate." : stringConcat({ parts: ["GOOGLE_SHEETS_API_ERROR (batchUpdate): ", resBatch.body] }).result

  rowNum = startIndex + 1
  rowNumStr = jsonStringify({ value: rowNum })
  range = stringConcat({ parts: [sheetName, "!A", rowNumStr.text] })
  encodedRange = urlEncode({ text: range.result })
  pathUpdate = stringConcat({ parts: ["/v4/spreadsheets/", spreadsheetId, "/values/", encodedRange.encoded, "?valueInputOption=USER_ENTERED"] })
  bodyUpdate = jsonStringify({ value: { values: rows } })

  resUpdate = isSuccess1 ? httpRequest({ host: "sheets.googleapis.com", method: "PUT", path: pathUpdate.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: bodyUpdate.text }) : { status: 400, body: "" }
  isHtml2 = stringIncludes({ haystack: stringLower({ text: resUpdate.body }).result, needle: "<html" })
  isSuccess2 = isSuccess1 ? (resUpdate.status == 200 ? true : false) : false
  errorBody2 = isSuccess1 ? (isHtml2.result ? "GOOGLE_SHEETS_API_ERROR: Received non-JSON response from values update." : stringConcat({ parts: ["GOOGLE_SHEETS_API_ERROR (values update): ", resUpdate.body] }).result) : errorBody1

  return isSuccess2 ? { success: true, result: resUpdate.body, error: "" } : { success: false, result: "", error: errorBody2 }
}

formatCells = (googleToken: string, spreadsheetId: string, sheetId: number, startRowIndex: number, endRowIndex: number, startColumnIndex: number, endColumnIndex: number, cell: {}, fields: string): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v4/spreadsheets/", spreadsheetId, ":batchUpdate"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { requests: [ { repeatCell: { range: { sheetId: sheetId, startRowIndex: startRowIndex, endRowIndex: endRowIndex, startColumnIndex: startColumnIndex, endColumnIndex: endColumnIndex }, cell: cell, fields: fields } } ] } })
  res = httpRequest({ host: "sheets.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_SHEETS_API_ERROR: Received non-JSON response from formatCells." : stringConcat({ parts: ["GOOGLE_SHEETS_API_ERROR (formatCells): ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

batchUpdateSpreadsheet = (googleToken: string, spreadsheetId: string, requests: {}[]): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v4/spreadsheets/", spreadsheetId, ":batchUpdate"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { requests: requests } })
  res = httpRequest({ host: "sheets.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_SHEETS_API_ERROR: Received non-JSON response from batchUpdateSpreadsheet." : stringConcat({ parts: ["GOOGLE_SHEETS_API_ERROR (batchUpdateSpreadsheet): ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}
