listFilesByFolder = (googleToken: string, folderId: string): { success: boolean, result: { id: string, name: string, mimeType: string }[], error: string } => {
  query = stringConcat({ parts: ["'", folderId, "' in parents and trashed = false"] })
  encodedQuery = urlEncode({ text: query.result })
  path = stringConcat({ parts: ["/drive/v3/files?q=", encodedQuery.encoded, "&fields=files(id,name,mimeType)"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "www.googleapis.com", method: "GET", path: path.result, headers: { "Authorization": auth.result } })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  shouldParse = isSuccess ? (isHtml.result ? false : true) : false
  parsed = shouldParse ? jsonParse({ text: res.body }) : { value: { files: [] } }
  files = parsed.value.files ? parsed.value.files : []
  apiErrorName = isHtml.result ? "GOOGLE_DRIVE_API_ERROR: Received non-JSON response. Check token secret name and Drive scopes." : stringConcat({ parts: ["GOOGLE_DRIVE_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: files, error: "" } : { success: false, result: [], error: apiErrorName }
}

searchDrive = (googleToken: string, query: string): { success: boolean, result: { id: string, name: string, mimeType: string }[], error: string } => {
  hasEquals = stringIncludes({ haystack: query, needle: "=" }).result
  hasContains = stringIncludes({ haystack: query, needle: "contains" }).result
  hasIn = stringIncludes({ haystack: query, needle: "in" }).result
  isFormattedQuery = hasEquals ? true : (hasContains ? true : (hasIn ? true : false))

  rawQuery = isFormattedQuery ? query : stringConcat({ parts: ["fullText contains '", query, "'"] }).result
  hasTrashed = stringIncludes({ haystack: rawQuery, needle: "trashed" }).result
  fullQuery = hasTrashed ? rawQuery : stringConcat({ parts: [rawQuery, " and trashed = false"] }).result
  encodedQuery = urlEncode({ text: fullQuery.result })
  path = stringConcat({ parts: ["/drive/v3/files?q=", encodedQuery.encoded, "&fields=files(id,name,mimeType)&pageSize=20"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "www.googleapis.com", method: "GET", path: path.result, headers: { "Authorization": auth.result } })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  shouldParse = isSuccess ? (isHtml.result ? false : true) : false
  parsed = shouldParse ? jsonParse({ text: res.body }) : { value: { files: [] } }
  files = parsed.value.files ? parsed.value.files : []
  apiErrorName = isHtml.result ? "GOOGLE_DRIVE_API_ERROR: Received non-JSON response. Check token secret name and Drive scopes." : stringConcat({ parts: ["GOOGLE_DRIVE_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: files, error: "" } : { success: false, result: [], error: apiErrorName }
}
