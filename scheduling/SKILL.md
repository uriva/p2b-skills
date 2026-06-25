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

All functions require a token parameter that must be mapped to a bot secret via
`secretMapping`. The exact secret names vary per bot. To find the correct name:

1. Call `secrets_and_variables/list_env_variables`
2. Pick the secret whose hosts match the service you need:
   - **Google Calendar / Google Sheets**: look for a secret with host
     `www.googleapis.com`
   - **Calendly**: look for a secret with host `api.calendly.com`
   - **Microsoft 365**: look for a secret with host `graph.microsoft.com`
3. Pass that secret name in `secretMapping` (e.g.
   `{ "googleToken": "GOOGLE_WORKSPACE_TOKEN" }`)

Do not guess secret names. Do not pass env var names like
`GOOGLE_CALENDAR_TOKEN` as token values. Always discover the name first.

Example:

```
# 1. Discover secrets
secrets_and_variables/list_env_variables

# 2. Use the discovered Google Calendar secret (example: "GOOGLE_WORKSPACE_TOKEN")
searchCalendarEvents("GOOGLE_WORKSPACE_TOKEN", "primary", "meeting", "2026-04-19T00:00:00Z", "2026-04-20T00:00:00Z")
```

## Scheduling Constraints

- **Never use `setTimeout` or `setInterval` in a Deno isolate:** Deno isolates on prompt2bot are short-lived, ephemeral, and stateless. Using `setTimeout` or `setInterval` to schedule actions or trigger delayed logic will not fire reliably, as the isolate can spin down immediately after the main handler returns. For scheduled, delayed, or recurring tasks, always use platform-level scheduling (such as the prompt2bot `create-remote-task` API or appropriate task queues) instead of in-memory timers.
