searchCalendarEvents = (googleToken: string, calendarId: string, query: string, timeMin: string, timeMax: string): { success: boolean, result: { id: string, summary: string, start: string, end: string, link: string }[], error: string } => {
  encodedQuery = urlEncode({ text: query })
  encodedTimeMin = urlEncode({ text: timeMin })
  encodedTimeMax = urlEncode({ text: timeMax })
  searchParams = stringConcat({ parts: ["q=", encodedQuery.encoded, "&timeMin=", encodedTimeMin.encoded, "&timeMax=", encodedTimeMax.encoded, "&singleEvents=true&orderBy=startTime&maxResults=250"] })
  path = stringConcat({ parts: ["/calendar/v3/calendars/", calendarId, "/events?", searchParams.result] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "www.googleapis.com", method: "GET", path: path.result, headers: { "authorization": auth.result } })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  shouldParse = isSuccess ? (isHtml.result ? false : true) : false
  parsed = shouldParse ? jsonParse({ text: res.body }) : { value: { items: [] } }
  items = parsed.value.items ? parsed.value.items : []
  apiErrorSummary = isHtml.result ? "GOOGLE_CALENDAR_API_ERROR: Received non-JSON response. Check the token secret name and Google Calendar scopes." : stringConcat({ parts: ["GOOGLE_CALENDAR_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: items, error: "" } : { success: false, result: [], error: apiErrorSummary }
}

createCalendarEvent = (googleToken: string, calendarId: string, summary: string, desc: string, start: string, endTime: string, location: string): { success: boolean, result: { id: string, link: string }, error: string } => {
  path = stringConcat({ parts: ["/calendar/v3/calendars/", calendarId, "/events"] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  body = jsonStringify({ value: { summary: summary, description: desc, location: location, start: { dateTime: start }, end: { dateTime: endTime } } })
  res = httpRequest({ host: "www.googleapis.com", method: "POST", path: path.result, headers: { "authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  shouldParse = isSuccess ? (isHtml.result ? false : true) : false
  parsed = shouldParse ? jsonParse({ text: res.body }) : { value: { id: "", htmlLink: "" } }
  apiErrorLink = isHtml.result ? "GOOGLE_CALENDAR_API_ERROR: Received non-JSON response. Check the token secret name and Google Calendar scopes." : stringConcat({ parts: ["GOOGLE_CALENDAR_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: { id: parsed.value.id, link: parsed.value.htmlLink }, error: "" } : { success: false, result: { id: "", link: "" }, error: apiErrorLink }
}

updateCalendarEvent = (googleToken: string, calendarId: string, eventId: string, summary: string, desc: string, location: string): { success: boolean, result: { id: string, link: string }, error: string } => {
  path = stringConcat({ parts: ["/calendar/v3/calendars/", calendarId, "/events/", eventId] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  updates = pick({ obj: { summary: summary, description: desc, location: location }, keys: ["summary", "description", "location"] })
  body = jsonStringify({ value: updates.result })
  res = httpRequest({ host: "www.googleapis.com", method: "PATCH", path: path.result, headers: { "authorization": auth.result, "content-type": "application/json" }, body: body.text })
  isHtml = stringIncludes({ haystack: stringLower({ text: res.body }).result, needle: "<html" })
  isSuccess = res.status == 200 ? true : false
  shouldParse = isSuccess ? (isHtml.result ? false : true) : false
  parsed = shouldParse ? jsonParse({ text: res.body }) : { value: { id: "", htmlLink: "" } }
  apiErrorLink = isHtml.result ? "GOOGLE_CALENDAR_API_ERROR: Received non-JSON response. Check the token secret name and Google Calendar scopes." : stringConcat({ parts: ["GOOGLE_CALENDAR_API_ERROR: ", res.body] }).result
  return isSuccess ? { success: true, result: { id: parsed.value.id, link: parsed.value.htmlLink }, error: "" } : { success: false, result: { id: "", link: "" }, error: apiErrorLink }
}

deleteCalendarEvent = (googleToken: string, calendarId: string, eventId: string): { success: boolean } => {
  path = stringConcat({ parts: ["/calendar/v3/calendars/", calendarId, "/events/", eventId] })
  auth = stringConcat({ parts: ["Bearer ", googleToken] })
  res = httpRequest({ host: "www.googleapis.com", method: "DELETE", path: path.result, headers: { "authorization": auth.result } })
  return { success: res.status == 204 }
}
