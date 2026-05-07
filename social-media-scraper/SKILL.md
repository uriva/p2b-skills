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
