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
- **Optimize mobile first:** On channels where users arrive on mobile (WhatsApp, X/Twitter, Reddit mobile), a clean **sticky mobile CTA bar** often drives 25%-40% of total clicks. Track it separately (`mobile_sticky_bar`) so you can verify its share.

## Turning Blog Readers Into Product Users

Technical blog posts often get strong search and community traffic while converting at `<2%` because they end with a cold generic `/login` button.

- Add a **lightweight top strip** linking directly to the flagship try-now experience (`location="top_strip"`).
- Replace generic bottom signup boxes with a **product-first bottom CTA** featuring equal-sized Try Now + Live Demo buttons (`location="blog_post_cta"`, `location="bottom_cta"`).
- Keep the tone editorial and helpful — never pop up aggressive modals that alienate developer readers.

## Web Engineering Gotchas That Silently Break CRO

- **Prerender / SSR hydration with query params:** On statically prerendered pages (`?ref=...`, `?utm_source=...`, `?token=...`), never read `location.search` during the initial render pass — runtime DOM mismatch corrupts hydration and breaks click handlers. Read query params after mount and preserve SSR-safe fallback links.
- **Verify past CDN caches:** Static hosts and CDNs frequently cache HTML for several minutes (`s-maxage=300`). Always verify fresh deploys with a cache-busting query string (`?v=<timestamp>`) and inspect rendered markup before announcing a launch or sharing on communities.
- **Respect experiment bake windows:** Do not redesign or churn a landing page or CTA that changed `<24h` ago unless telemetry shows a broken click path, hydration bug, or JS exception. Small samples (`<30-50` visits) fluctuate wildly with traffic source mix.
