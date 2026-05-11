searchMicrosoftCalendarEvents = (microsoftToken: string, query: string, timeMin: string, timeMax: string): { success: boolean, result: { id: string, subject: string, start: string, end: string, webLink: string }[], error: string } => {
  encodedQuery = urlEncode({ text: query })
  encodedTimeMin = urlEncode({ text: timeMin })
  encodedTimeMax = urlEncode({ text: timeMax })
  searchParams = stringConcat({ parts: ["startDateTime=", encodedTimeMin.encoded, "&endDateTime=", encodedTimeMax.encoded, "&$search=\"", encodedQuery.encoded, "\"&$orderby=start/dateTime&$top=250"] })
  path = stringConcat({ parts: ["/v1.0/me/calendarView?", searchParams.result] })
  auth = stringConcat({ parts: ["Bearer ", microsoftToken] })
  res = httpRequest({ host: "graph.microsoft.com", method: "GET", path: path.result, headers: { "authorization": auth.result, "prefer": "outlook.timezone=\"UTC\"" } })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  shouldParse = isSuccess ? (isHtml.result ? false : true) : false
  parsed = shouldParse ? jsonParse({ text: res.body }) : { value: { value: [] } }
  items = parsed.value.value ? parsed.value.value : []
  apiErrorSummary = isHtml.result ? "MICROSOFT_CALENDAR_API_ERROR: Received non-JSON response. Check the token secret name and Microsoft Graph scopes." : stringConcat({ parts: ["MICROSOFT_CALENDAR_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: items, error: "" } : { success: false, result: [], error: apiErrorSummary }
}

createMicrosoftCalendarEvent = (microsoftToken: string, subject: string, body_: string, start: string, endTime: string, location: string): { success: boolean, result: { id: string, webLink: string }, error: string } => {
  auth = stringConcat({ parts: ["Bearer ", microsoftToken] })
  body = jsonStringify({ value: { subject: subject, body: { contentType: "text", content: body_ }, location: { displayName: location }, start: { dateTime: start, timeZone: "UTC" }, end: { dateTime: endTime, timeZone: "UTC" } } })
  res = httpRequest({ host: "graph.microsoft.com", method: "POST", path: "/v1.0/me/events", headers: { "authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 201 ? true : false
  shouldParse = isSuccess ? (isHtml.result ? false : true) : false
  parsed = shouldParse ? jsonParse({ text: res.body }) : { value: { id: "", webLink: "" } }
  apiErrorLink = isHtml.result ? "MICROSOFT_CALENDAR_API_ERROR: Received non-JSON response. Check the token secret name and Microsoft Graph scopes." : stringConcat({ parts: ["MICROSOFT_CALENDAR_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: { id: parsed.value.id, webLink: parsed.value.webLink }, error: "" } : { success: false, result: { id: "", webLink: "" }, error: apiErrorLink }
}

updateMicrosoftCalendarEvent = (microsoftToken: string, eventId: string, subject: string, body_: string, location: string): { success: boolean, result: { id: string, webLink: string }, error: string } => {
  path = stringConcat({ parts: ["/v1.0/me/events/", eventId] })
  auth = stringConcat({ parts: ["Bearer ", microsoftToken] })
  updates = pick({ obj: { subject: subject, body: { contentType: "text", content: body_ }, location: { displayName: location } }, keys: ["subject", "body", "location"] })
  body = jsonStringify({ value: updates.result })
  res = httpRequest({ host: "graph.microsoft.com", method: "PATCH", path: path.result, headers: { "authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  shouldParse = isSuccess ? (isHtml.result ? false : true) : false
  parsed = shouldParse ? jsonParse({ text: res.body }) : { value: { id: "", webLink: "" } }
  apiErrorLink = isHtml.result ? "MICROSOFT_CALENDAR_API_ERROR: Received non-JSON response. Check the token secret name and Microsoft Graph scopes." : stringConcat({ parts: ["MICROSOFT_CALENDAR_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: { id: parsed.value.id, webLink: parsed.value.webLink }, error: "" } : { success: false, result: { id: "", webLink: "" }, error: apiErrorLink }
}

deleteMicrosoftCalendarEvent = (microsoftToken: string, eventId: string): { success: boolean } => {
  path = stringConcat({ parts: ["/v1.0/me/events/", eventId] })
  auth = stringConcat({ parts: ["Bearer ", microsoftToken] })
  res = httpRequest({ host: "graph.microsoft.com", method: "DELETE", path: path.result, headers: { "authorization": auth.result } })
  return { success: res.status == 204 }
}
