---
name: scheduling
description: AI agent skill for scheduling meetings via Calendly and Google Calendar.
---

# Scheduling Skill

Tools for checking availability and scheduling meetings through Calendly and
Google Calendar.

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

## Usage

Pass secret names as the token parameters:

- For Calendly: pass `"calendly-token"` as the `calendlyToken` parameter
- For Google Calendar: pass `"google-calendar"` as the `googleToken` parameter

Do not pass env var names like `GOOGLE_CALENDAR_TOKEN` or `CALENDLY_TOKEN` as
token values. The skill expects the configured secret name, and using env var
names will cause auth failures.

Example:

```
getCalendlyEventTypes("calendly-token")
searchCalendarEvents("google-calendar", "primary", "meeting", "2026-04-19T00:00:00Z", "2026-04-20T00:00:00Z")
```
