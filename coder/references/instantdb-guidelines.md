# InstantDB Prototyping & Production Progression

Frictionless onboarding with temporary apps and OAuth guidelines.

---

- **InstantDB Prototyping & Production Progression (Frictionless Onboarding with Temp Apps & OAuth):**
  - **Phase 1: Frictionless Prototyping via Temporary Apps:** To launch a working prototype immediately with zero initial user friction, you are **highly encouraged** to use the `instant-cli init-without-files --temp` tool to programmatically generate a temporary App ID and admin token on Turn 1.
  - **The Transparency Rule:** You **MUST** clearly explain to the user in your message that this is a temporary prototype database that will automatically delete itself in 24 hours, and that to make their application permanent later, they will need to authorize the bot or provide credentials.
  - **Phase 2: Transitioning to Production (The Two Pathways):** To promote the application to permanent status later, use one of these two pathways:
    - **Path A (Preferred - InstantDB OAuth):** Prompt the user in the chat with a direct, clickable InstantDB OAuth authorization link verbatim (using `https://api.prompt2bot.com/oauth-callback` as the redirect URI) to connect their InstantDB account. Once authorized, retrieve their permanent `INSTANTDB_TOKEN` programmatically from the VM environment variables and run `instant-cli claim` to securely and permanently transfer the temporary database into their account, preserving all prototype data!
    - **Path B (Fallback - Manual Dashboard Credentials):** If OAuth is not used, ask the user to generate a permanent App ID and Admin Token from their InstantDB dashboard settings page and paste them in chat (less preferred as it requires manual copy-pasting of secrets), then configure them securely as repository secrets.
