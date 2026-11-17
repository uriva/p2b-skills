import { updateCalendarEvent } from "../scripts/google-calendar.ss"
import { updateMicrosoftCalendarEvent } from "../scripts/microsoft-calendar.ss"

mockGooglePatch = (host, method, path, headers, body) => {
  parsed = jsonParse({ text: body })
  hasStart = parsed.value.start ? parsed.value.start.dateTime == "2026-11-18T13:00:00+02:00" : false
  hasEnd = parsed.value.end ? parsed.value.end.dateTime == "2026-11-18T14:00:00+02:00" : false
  wipesSummary = parsed.value.summary == ""
  ok = method == "PATCH" ? (hasStart ? (hasEnd ? (wipesSummary ? false : true) : false) : false) : false
  return ok ? { status: 200, body: "{\"id\":\"evt-1\",\"htmlLink\":\"https://calendar.example.com/evt-1\"}" } : { status: 400, body: body }
}

reschedulesGoogleEventWithoutWipingFields = () => {
  f = override(updateCalendarEvent, { httpRequest: mockGooglePatch })
  res = f({ googleToken: "tok", calendarId: "primary", eventId: "evt-1", start: "2026-11-18T13:00:00+02:00", endTime: "2026-11-18T14:00:00+02:00" })
  assert({ condition: res.success == true, message: "expected Google Calendar reschedule PATCH to include start/end without wiping summary" })
  return true
}

mockMicrosoftPatch = (host, method, path, headers, body) => {
  parsed = jsonParse({ text: body })
  hasStart = parsed.value.start ? parsed.value.start.dateTime == "2026-11-18T11:00:00Z" : false
  hasEnd = parsed.value.end ? parsed.value.end.dateTime == "2026-11-18T12:00:00Z" : false
  wipesSubject = parsed.value.subject == ""
  ok = method == "PATCH" ? (hasStart ? (hasEnd ? (wipesSubject ? false : true) : false) : false) : false
  return ok ? { status: 200, body: "{\"id\":\"ms-evt-1\",\"webLink\":\"https://outlook.example.com/ms-evt-1\"}" } : { status: 400, body: body }
}

reschedulesMicrosoftEventWithoutWipingFields = () => {
  f = override(updateMicrosoftCalendarEvent, { httpRequest: mockMicrosoftPatch })
  res = f({ microsoftToken: "tok", eventId: "ms-evt-1", start: "2026-11-18T11:00:00Z", endTime: "2026-11-18T12:00:00Z" })
  assert({ condition: res.success == true, message: "expected Microsoft Calendar reschedule PATCH to include start/end without wiping subject" })
  return true
}
