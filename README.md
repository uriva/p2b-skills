# p2b-skills

Community skills for Prompt2Bot agents.

## Skills

- `github/` - read and edit GitHub repositories through the GitHub REST API.
- `google-docs/` - interact with Google Docs and Google Sheets.
- `google-drive/` - search and list Google Drive files.
- `scheduling/` - schedule and inspect availability with Calendly and Google Calendar.

Each skill directory has its own `tank.json`. CI discovers every `*/tank.json`
and runs `tank publish` from that directory.
