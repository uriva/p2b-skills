---
name: p2b-social-media-scraper
description: AI agent skill for searching Facebook posts and scraping LinkedIn profiles via Bright Data.
---

# Social Media Scraper Skill

Query Facebook posts via RapidAPI and scrape LinkedIn profiles via Bright Data.
All logic runs as safescript with no subprocess access.

Pass secrets via `secretMapping`:

```json
{ "rapidApiKey": "RAPIDAPI_KEY", "brightDataToken": "BRIGHTDATA_TOKEN" }
```

## Getting API Keys

### RapidAPI

Used by `facebookPosts` and `youtubeSubtitles`.

When a RapidAPI key is missing, explain clearly that this is an external API key
the owner needs to create in RapidAPI, not a password for Facebook or YouTube.
Do not say "if you already have one" as the main path; most owners will need to
create it now. Give the setup steps plainly and in the user's language, and
include the direct subscription link the user needs to open.

Good explanation:

> To pull Facebook post data reliably I need access to a RapidAPI provider.
> RapidAPI is a marketplace for APIs; you create a free RapidAPI account,
> subscribe to the Facebook Scraper v3 API at
> https://rapidapi.com/restyler/api/facebook-scraper3, copy your RapidAPI key,
> and send it here. I will store it securely as a bot secret named
> `RAPIDAPI_KEY` and use it only for these API calls.

Do not present browser scraping as an equivalent fallback when the task needs
structured Facebook engagement data. Facebook often blocks browser automation;
for reliable post/engagement analysis, guide the owner through RapidAPI setup.

1. Go to [rapidapi.com](https://rapidapi.com) and create a free account.
2. Subscribe (free tier) to the APIs you need:
   - [Facebook Scraper v3](https://rapidapi.com/restyler/api/facebook-scraper3) — for Facebook posts
   - [YouTube Media Downloader](https://rapidapi.com/ytjar/api/youtube-media-downloader) — for YouTube subtitles
3. Copy your API key from the [RapidAPI dashboard](https://rapidapi.com/developer/dashboard).
4. Add it as a bot secret (e.g. name `RAPIDAPI_KEY`) with no host restrictions.

When the owner sends the key, immediately store it with the secret-storage tool
as `RAPIDAPI_KEY`. Then call the relevant tool with
`secretMapping: { "rapidApiKey": "RAPIDAPI_KEY" }` instead of asking for the key
again.

### Bright Data

Used by `startLinkedInProfileScrape` and `getLinkedInProfileSnapshot`.

1. Go to [brightdata.com](https://brightdata.com) and create an account.
2. Get your API token from the [Bright Data dashboard](https://brightdata.com/cp/settings).
3. Add it as a bot secret (e.g. name `BRIGHTDATA_TOKEN`) with host `api.brightdata.com`.

## Tools

- `facebookPosts` — Search or get Facebook posts. Pass `query` and/or `groupId`.
- `startLinkedInProfileScrape` — Start a LinkedIn profile scrape (max 10 URLs).
  Returns a `snapshot_id` for polling.
- `getLinkedInProfileSnapshot` — Fetch status/result of a pending snapshot.

- `youtubeSubtitles` — Fetch SRT subtitles for a YouTube video URL.

## Example usage

```typescript
import { facebookPosts } from "./scripts/social-media-scraper.ss";

export const myTask = async () => {
  const result = await facebookPosts(
    process.env.RAPIDAPI_KEY,
    "deno programming",
    "",
    "",
  );
  console.log(result);
};
```

## Facebook

The `facebookPosts` function accepts:

- `rapidApiKey` — RapidAPI key
- `query` — Search query (empty string to omit)
- `groupId` — Facebook group ID (empty string to omit)
- `sortingOrder` — Sorting order for group posts, e.g. `CHRONOLOGICAL`

At least one of `query` or `groupId` must be non-empty.

## LinkedIn

Two-step flow:

1. Call `startLinkedInProfileScrape(brightDataToken, urls)` with up to 10 URLs.
2. If the response contains a `snapshot_id`, call
   `getLinkedInProfileSnapshot(brightDataToken, snapshotId)` to check progress.
   Repeat until `status` is `"ready"` or `"failed"`.

Valid LinkedIn URL format: `https://(www.)linkedin.com/in/<username>/`

## YouTube

Fetch subtitles for a single YouTube video:

- `youtubeSubtitles(rapidApiKey, url)` — Returns SRT subtitle text for a YouTube video URL.
  The URL must contain a video ID (e.g. `https://youtube.com/watch?v=abc`).
