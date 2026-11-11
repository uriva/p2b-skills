# p2b-skills

Community skills for [Prompt2Bot](https://prompt2bot.com) agents, powered by **Safescript** (`@uri/safescript`) for zero-VM, statically verified host-scoped tool execution. Click **Launch Agent** on any skill below to spin up a live agent on WhatsApp, Telegram, or Web in one click.

## Skills

- `personal-assistant/` — personal assistant setup, privacy, memory, channels, email, and OAuth guidance. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-personal-assistant)
- `coder/` — coding and integration guidelines for Prompt2Bot builder agents. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-coder)
- `japan-tourism/` — Japan travel guide for Tokyo tourists. Food and activity recommendations using Google My Maps integration. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=https%3A%2F%2Fgithub.com%2Furiva%2Fp2b-skills%2Ftree%2Fmain%2Fjapan-tourism)
- `vietnam-tourism/` — Vietnam travel guide covering destinations, itineraries, visas, money, and logistics. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=https%3A%2F%2Fgithub.com%2Furiva%2Fp2b-skills%2Ftree%2Fmain%2Fvietnam-tourism)
- `sinai-tourism/` — Sinai travel guide for tourists and vacationers. Camps, beaches, border logistics, and travel partner matching. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=https%3A%2F%2Fgithub.com%2Furiva%2Fp2b-skills%2Ftree%2Fmain%2Fsinai-tourism)
- `scheduling/` — schedule and inspect availability with Calendly, Google Calendar, and Microsoft 365 Calendar. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-scheduling)
- `gmail/` — read, search, and send Gmail messages. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-gmail)
- `google-docs/` — interact with Google Docs and Google Sheets. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-google-docs)
- `google-drive/` — search and list Google Drive files. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-google-drive)
- `github/` — read and edit GitHub repositories through the GitHub REST API. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-github)
- `shopify/` — manage Shopify products, orders, and customers. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-shopify)
- `social-media-scraper/` — search Facebook posts and scrape LinkedIn profiles via Bright Data. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-social-media-scraper)
- `document-pipeline/` — guidelines and best practices for building document ingestion, parsing, and extraction pipelines. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=tank%3A%40uriva%2Fp2b-document-pipeline)
- `haskalah/` — guidance, core curriculum (Limudei Liba), rational inquiry, and practical independence resources for Ultra-Orthodox (Haredi) Jews looking to expand their horizons, grounded in `https://haskalah.pages.dev/`. [Launch Agent →](https://prompt2bot.com/talk-to-skill?url=https%3A%2F%2Fgithub.com%2Furiva%2Fp2b-skills%2Ftree%2Fmain%2Fhaskalah)

Each skill directory has its own `tank.json`. CI discovers every `*/tank.json`
and runs `tank publish` from that directory.
