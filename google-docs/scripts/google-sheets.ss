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
