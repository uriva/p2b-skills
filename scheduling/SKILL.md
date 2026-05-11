---
name: scheduling
description: AI agent skill for scheduling meetings via Calendly, Google Calendar, and Microsoft 365 Calendar (Outlook).
---

# Scheduling Skill

Tools for checking availability and scheduling meetings through Calendly,
Google Calendar, and Microsoft 365 Calendar.

## Calendly Functions

### getCalendlyEventTypes(calendlyToken)

Returns `{ success, result, error }` where `result` contains available event
types.

### getCalendlyAvailableSlots(calendlyToken, startTime, endTime)

Returns `{ success, result, error }` where `result` contains available slots.
`startTime` and `endTime` are ISO timestamps.

## Google Calendar Functions

### searchCalendarEvents(googleToken, calendarId, query, timeMin, timeMax)

Search events in a calendar and return `{ success, result, error }`.
`timeMin`/`timeMax` are ISO timestamps.

### createCalendarEvent(googleToken, calendarId, summary, desc, start, endTime, location)

Create a new calendar event and return `{ success, result, error }`.

### updateCalendarEvent(googleToken, calendarId, eventId, summary, desc, location)

Update an existing event and return `{ success, result, error }`. Only provide
fields to change.

### deleteCalendarEvent(googleToken, calendarId, eventId)

Delete an event from the calendar.

## Microsoft 365 Calendar Functions

All Microsoft functions operate on the signed-in user's default calendar
(`/me/...` in Microsoft Graph). The OAuth token must have been issued with the
`Calendars.ReadWrite` scope (alias: `calendar`) for write operations, or
`Calendars.Read` (alias: `calendar_readonly`) for read-only operations. All
times are interpreted as UTC.

### searchMicrosoftCalendarEvents(microsoftToken, query, timeMin, timeMax)

Search events in the user's calendar within a time window. `timeMin`/`timeMax`
are ISO timestamps. Returns `{ success, result, error }` where `result` is an
array of events with `id`, `subject`, `start`, `end`, `webLink`.

### createMicrosoftCalendarEvent(microsoftToken, subject, body, start, endTime, location)

Create a new event. `start` and `endTime` are ISO timestamps. Returns
`{ success, result, error }` where `result` has `id` and `webLink`.

### updateMicrosoftCalendarEvent(microsoftToken, eventId, subject, body, location)

Update an existing event. Only the provided fields are changed.

### deleteMicrosoftCalendarEvent(microsoftToken, eventId)

Delete an event from the user's calendar.

## Usage

Pass secret names as the token parameters:

- For Calendly: pass `"calendly-token"` as the `calendlyToken` parameter
- For Google Calendar: pass `"google-calendar"` as the `googleToken` parameter
- For Microsoft 365 Calendar: pass `"microsoft-calendar"` as the
  `microsoftToken` parameter

Do not pass env var names like `GOOGLE_CALENDAR_TOKEN`, `CALENDLY_TOKEN`, or
`MICROSOFT_CALENDAR_TOKEN` as token values. The skill expects the configured
secret name, and using env var names will cause auth failures.

Example:

```
getCalendlyEventTypes("calendly-token")
searchCalendarEvents("google-calendar", "primary", "meeting", "2026-04-19T00:00:00Z", "2026-04-20T00:00:00Z")
searchMicrosoftCalendarEvents("microsoft-calendar", "meeting", "2026-04-19T00:00:00Z", "2026-04-20T00:00:00Z")
```
