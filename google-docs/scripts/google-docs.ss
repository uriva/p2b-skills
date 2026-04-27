fetchDocument = (googleToken: string, documentId: string): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v1/documents/", documentId] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "docs.googleapis.com", method: "GET", path: path.result, headers: { "Authorization": auth.result } })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

createDocument = (googleToken: string, title: string): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v1/documents"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { title: title } })
  res = httpRequest({ host: "docs.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}

executeBatchUpdate = (googleToken: string, documentId: string, requestsBody: string): { success: boolean, result: string, error: string } => {
  path = stringConcat({ parts: ["/v1/documents/", documentId, ":batchUpdate"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "docs.googleapis.com", method: "POST", path: path.result, headers: { "Authorization": auth.result, "content-type": "application/json" }, body: requestsBody })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  errorBody = isHtml.result ? "GOOGLE_DOCS_API_ERROR: Received non-JSON response. Check token secret name and Docs scopes." : stringConcat({ parts: ["GOOGLE_DOCS_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorBody }
}
