# Organic Content, SEO/AI Search & Safe Community Distribution

## Writing Technical Content That Ranks & Converts

Search engines and AI answer engines reward concrete engineering depth over generic "Top 10" marketing fluff.

- **Target high-intent problem & architecture queries:** Focus on topics your ICP actively searches when hitting a wall:
  - *"How to do X without self-hosting / without breaking Y"*
  - *"Why we don't do X (contrarian architectural trade-off)"*
  - *"Alternative to [popular DIY/open-source tool] with zero setup"*
  - Real benchmarks, failure modes, security/isolation models, and production postmortems.
- **Write in an authentic peer voice:** Casual, conversational, opinionated, concise. Take clear stances without hedging ("it might be", "perhaps"). Frame your own product matter-of-factly as a practical example of the architecture ("Here's what this looks like in practice"), never as a humble-brag or press release.
- **Avoid AI-slop tells:** Skip em-dash overuse, forced staccato fragments, dramatic "In today's fast-paced world" openings, and bloated summaries. Say what needs to be said and stop.
- **Always publish complete metadata:** Keep sitemap, structured metadata/OG images, `llms.txt`, and internal links to your flagship landing page and zero-auth demos updated with every new post.

## Safe Community Distribution (Reddit & Developer Forums)

Technical communities (like `r/AI_Agents`, `r/aiagents`, `r/LLMDevs`, `r/AgentsOfAI`, `r/PromptEngineering`) can drive highly qualified traffic — and will permanently ban accounts that behave like automated spammers.

### Hard Anti-Ban Guardrails (Non-Negotiable)

1. **Account-wide cooldown (`>= 24 hours`):** Before submitting anything, inspect the account's recent submission history (including posts made by the founder manually!). Post **only** if the latest submission anywhere on the account is at least 24 hours old.
2. **Per-subreddit cooldown (`>= 48 hours`):** Never submit to the same subreddit twice within 48 hours, and never re-share a topic already posted to that subreddit.
3. **Zero cross-post bursts:** Never blast the same post across 3-5 subreddits in one run. One thoughtful post to one welcoming community per eligible cycle.
4. **Maintain an explicit allowlist and denylist:** Track which subreddits welcome builder technical writeups and which auto-remove them via moderators/filters. Never retry a subreddit that removed a previous post, and never try to bypass a captcha or block.
5. **Pre-flight live URL verification:** Confirm the live blog post returns HTTP `200` and renders the product CTA cleanly *before* submitting.

### Post Format That Earns Upvotes Instead of Bans

- **Zero links in the post body:** Write a standalone, opinionated technical self-post that gives 100% of the core insight right inside the thread — no links, no promo pitch, no "check out my SaaS".
- **One transparent follow-up comment:** Right after submitting, add a single short comment with the link to the full writeup/diagrams for anyone who wants the deeper reference.
- **Engage like a human engineer:** Check unread replies on active threads each cycle. When someone asks a genuine technical question or raises a smart counter-argument, leave a brief, candid technical reply with **zero links and zero sales pitch**. Ignore trolls.
- **Clean up browser sessions:** Always close temporary browser tabs opened during checks or submissions.
