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
- **Audit technical SEO basics before writing new content:** Check `robots.txt` and `sitemap.xml` (frequently 404 on static SPAs), confirm every prerendered route has a unique `<title>`, `<meta name="description">`, OG tags, `<link rel="canonical">`, `noindex` on private/settings pages, and `SoftwareApplication` + `FAQPage` JSON-LD. Auto-generate `sitemap.xml` and per-route head metadata from one route registry so they never drift.
- **Include current pricing & plans in `/llms.txt`:** AI answer engines (ChatGPT, Gemini, Perplexity) and coding agents read `/llms.txt` directly — include accurate free-tier limits, credit packs, and pricing URLs so AI referrals arrive with accurate expectations.
- **Launch prerendered use-case pages from real user demand:** Mine actual user queries and chat logs to build focused, prerendered use-case landing pages (each with an interactive search/try bar pre-seeded with niche starter prompts and subtle homepage footer links) rather than guessing generic keywords.
- **Always publish complete metadata:** Keep sitemap, structured metadata/OG images, `llms.txt`, and internal links to your flagship landing page and zero-auth demos updated with every new post.
- **Host flagship essays on your own domain and consolidate canonicals:** Publish HN/community engineering essays directly on your own domain (`/blog/...`) so 100% of launch traffic, backlinks, and AI citations accrue to you. When syndicating to platforms like Dev.to, explicitly set `canonical_url` back to your domain's post and verify the live `<link rel="canonical">` tag.

## Developer & AI Agent Ecosystem Distribution

For developer tools and agent infrastructure, native ecosystem surfaces compound organically and often beat cold social promo:

- **Mine production data to find your organic harness ICP:** Inspect real active/paying org names and usage patterns to discover which agent harnesses already adopt your product (e.g., Hermes Agent, OpenClaw, Claude Code, LangGraph), then build dedicated guides, skills, and native plugins for those exact ecosystems.
- **Ship standard AgentSkills and well-known discovery:** Publish a clean `skills/<name>/SKILL.md` in your repo (installable across Claude Code, Cursor, Hermes, OpenCode) and mirror it at `/.well-known/skills/index.json` + `/.well-known/skills/<name>/SKILL.md`.
- **Optimize Official MCP Registry & automated directory scores:** Publish a domain-verified `server.json` to the Official MCP Registry (`registry.modelcontextprotocol.io`), which auto-feeds downstream aggregators and IDE catalogs. Support unauthenticated `initialize` + `tools/list` schema discovery (while failing closed `401` on `tools/call`), include a crisp server icon, describe every input schema parameter, attach standard MCP tool `annotations` (`readOnlyHint`, `destructiveHint`, `idempotentHint`, `openWorldHint`), and claim domain maintainer badges on directories — complete metadata routinely lifts a server from page 10+ to top-of-category organically.
- **Follow curated plugin-catalog security hygiene upfront:** When submitting to human-reviewed marketplaces (e.g., Hermes Plugin Catalog), keep plugins zero-dependency where possible, read credentials only through the host's scoped secret API (never raw `os.environ` or `.env` files), disable HTTP redirects when sending Bearer tokens, gate persistent side effects (like webhook creation) behind human-approval hooks (`pre_tool_call`), and disclose all network/data behavior plainly.
- **Check cross-product dependencies before tightening shared API security:** When a community or marketplace reviewer flags a real prompt-injection/exfiltration vector (such as an untrusted agent creating a persistent webhook), audit sister products before breaking shared REST routes — harden the untrusted agent surface (e.g. restricting MCP account-scoped keys + adding harness approval gates) while keeping trusted backend REST integrations intact.

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
- **Engage like a human engineer:** Check unread replies on active threads each cycle. When someone asks a genuine technical question or raises a smart counter-argument, leave a brief, candid technical reply with **zero links and zero sales pitch**. Ignore trolls. When an engineer spots a legitimate security or architecture flaw, ship the real fix immediately and reply calmly thanking them with the commit link — publicly shipping real fixes from feedback builds far more developer trust than any landing copy.
- **Use pre-filled intent URLs for reliable social posting in browser automation:** Typing long posts character-by-character into rich editors (like X/Twitter Draft.js) frequently triggers timeouts; navigate to pre-populated intent URLs (e.g., `x.com/intent/tweet?text=...`) and click Post cleanly.
- **Clean up browser sessions:** Always close temporary browser tabs opened during checks or submissions.
- **Respect calendar and holiday timing:** Avoid launching high-leverage waves (like Show HN or B2B subreddits) on Friday afternoons or major US/EU holiday weekends; stagger waves across Tue-Thu 14:00-17:00 UTC peak windows.
- **Upgrade mobile share buttons to native OS share sheets:** On invite links, empty states, and public item pages, use `navigator.share` with clipboard fallback (treating user cancel silently) and log `surface` + `result` to measure viral K-factor.
