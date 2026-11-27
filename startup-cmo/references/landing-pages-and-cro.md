# Landing Pages, Zero-Auth Demos & CRO

## Eliminate Auth Walls Before Value

The single highest-leverage conversion win on most software/AI landing pages is letting visitors experience the core product **before** creating an account.

- Replace `"Sign up to try"` with a 1-click launch into a pre-filled live chat, interactive sandbox, or instant tool runner.
- If you have a directory/launcher page (e.g. launching a template, skill, or workflow), wire it straight to the live product with pre-filled context instead of gating it behind OAuth/magic-link login. Measure both CTA click rate and `Signin Error` drop to confirm the lift.

## Visual & Copy Discipline

- **Lead with the concrete differentiator:** Spell out what your product actually does that a generic browser chatbot or DIY script cannot (for example: its own computer/VM, real phone line, group chat presence, proactive outreach, zero self-hosting).
- **One cohesive visual palette:** Keep primary and secondary CTAs inside one unified brand color system — avoid jarring multi-color clashes (like random neon green buttons beside blue brand accents).
- **Equal visual weight for primary/secondary pairs:** When showing two sibling actions (e.g. "Try Now" + "See Demo"), keep button sizing, padding, and hierarchy balanced.
- **Cut clutter ruthlessly:** Strip generic SaaS comparison tables, repetitive fine-print disclaimers under buttons, vague buzzwords, and decorative fluff. Show real product artifacts (live interactive previews, concrete prompt chips, crisp editorial illustrations).
- **Optimize mobile first and inspect real screenshots:** Always render and inspect real mobile (`375x812`) and desktop (`1280x900`) screenshots of your landing page, sign-in wall, and `/pricing`. Verify (1) the primary CTA sits **above the mobile fold**, (2) primary OAuth buttons (like Google with its 4-color "G" mark) have unmistakable contrast vs secondary email forms, and (3) zero horizontal overflow occurs. On channels where users arrive on mobile (WhatsApp, X/Twitter, Reddit mobile), a clean header or sticky mobile CTA pill with a value-driven label (e.g. `"No Watermark"` instead of vague `"Pro"`) drives a major share of pricing visits.
- **Preserve user intent across auth & channel fallbacks:** Store pending queries (`?say=`) and checkout intents (`?subscribe=`) in `localStorage` with a short TTL (not just `sessionStorage`, which drops across mobile OAuth redirects and email magic-link tabs). When offering a no-sign-in fallback channel (like WhatsApp), pre-fill the user's pending query right into the link (`?text=<encoded query>`) so they never retype.
- **Turn delivered outputs into a viral + monetized share loop:** On media/artifact products, include 1-tap `Download` + branded `Share` links right next to every delivered output (fixing missing mobile `<video>` download buttons while routing shared links to a clean player page with a prominent upgrade CTA and an interactive "Try it yourself" search bar).

## Turning Blog Readers Into Product Users

Technical blog posts often get strong search and community traffic while converting at `<2%` because they end with a cold generic `/login` button.

- Add a **lightweight top strip** linking directly to the flagship try-now experience (`location="top_strip"`).
- Replace generic bottom signup boxes with a **product-first bottom CTA** featuring equal-sized Try Now + Live Demo buttons (`location="blog_post_cta"`, `location="bottom_cta"`).
- Keep the tone editorial and helpful — never pop up aggressive modals that alienate developer readers.

## Web Engineering Gotchas That Silently Break CRO

- **Prerender / SSR hydration with query params:** On statically prerendered pages (`?ref=...`, `?utm_source=...`, `?token=...`), never read `location.search` during the initial render pass — runtime DOM mismatch corrupts hydration and breaks click handlers. Read query params after mount and preserve SSR-safe fallback links.
- **Progressive-enhancement hero forms:** Add native `action="/app" method="get"` and `name="..."` attributes on hero search/prompt forms so fast submissions before JS hydration on slow mobile networks still navigate cleanly instead of reloading `/?`.
- **Never prerender a blank loading spinner on `/docs` or SEO pages:** Scope client-side loading spinners strictly to dynamic sub-sections (like OpenAPI endpoint lists) so static HTML immediately exposes the heading, quickstart, and pricing/token CTA to search crawlers and users.
- **Verify past CDN caches and silent build failures:** Static hosts often keep serving the previous build if a deploy fails and cache HTML for several minutes (`s-maxage=300`). Always check live deploy status and bundle hashes (`?v=<timestamp>`) before announcing a launch or evaluating metrics.
- **Respect experiment bake windows:** Do not redesign or churn a landing page or CTA that changed `<24h` ago unless telemetry shows a broken click path, hydration bug, or JS exception. Small samples (`<30-50` visits) fluctuate wildly with traffic source mix.
