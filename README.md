# p2b-skills

Community skills for Prompt2Bot agents.

## Skills

- `github/` - read and edit GitHub repositories through the GitHub REST API.
- `coder/` - coding and integration guidelines for Prompt2Bot builder agents.
- `document-pipeline/` - guidelines and best practices for building document ingestion, parsing, and extraction pipelines.
- `google-docs/` - interact with Google Docs and Google Sheets.
- `google-drive/` - search and list Google Drive files.
- `personal-assistant/` - personal assistant setup, privacy, memory, channels,
  email, and OAuth guidance.
- `scheduling/` - schedule and inspect availability with Calendly and Google
  Calendar.
- `social-media-scraper/` - search Facebook posts and scrape LinkedIn profiles
  via Bright Data.
- `japan-tourism/` - Japan travel guide for Tokyo tourists. Food and activity
  recommendations using Google My Maps integration.

Each skill directory has its own `tank.json`. CI discovers every `*/tank.json`
and runs `tank publish` from that directory.
