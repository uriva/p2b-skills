# Tech Stack & Project Structure

The default technology choices for anything you build, plus how to lay out the
repository. For the credential-acquisition and first-turn flow, see
`web-app-playbook.md`. For CI/source-of-truth wiring, see
`planning-and-design.md`.

---

## Project Structure

Use a **monorepo** when building a project with multiple components (e.g. server, frontend, shared types). Keep everything in a single Git repo with top-level directories for each component — e.g. `server/`, `web/`, `shared/`. Don't create separate repos for parts of the same project. This keeps dependencies in sync, simplifies deployment, and avoids cross-repo coordination headaches.

---

## Tech Stack

- **GitHub** for code hosting. Always create repositories as **private**. You are **strictly forbidden** from creating public repositories unless the user has explicitly requested it in the chat. Use the native `gh` CLI on the VM for GitHub API operations (create repos, list repos, issues, PRs). For downloading and uploading code, use curl with the GitHub Contents API.
- **Deno Deploy** for most things: microservices, cron jobs, dashboard backends, webhook responders/senders. Deno also supports Next.js apps for frontends. The only exception is when you need Docker or long-running operations. Use the native `deno deploy` subcommand on the VM for all Deno Deploy operations (create apps, deploy, set env vars). Never use `deployctl` — it is deprecated.
- **Google Cloud Tasks / Pub/Sub** for long-running operations triggered by webhooks, or for large numbers of user-generated scheduled actions. Never use Deno cron for user-generated recurring tasks — only for small numbers of system-level jobs. See `scheduling-and-media.md` for the full scheduling decision matrix.
- **InstantDB** for databases. Use the `instant-cli` on the VM for queries and schema/perms management, and curl for transact (database writes). Set up CI to push schema and perms from main automatically. Never use spreadsheets, Airtable, or Notion databases as a data store — see the "Anti-Pattern: Spreadsheets" section in `scheduling-and-media.md`. If the user needs data visibility, build them an admin dashboard with Next.js and InstantDB.
- **Next.js (App Router, SSR)** for all frontends — dashboards, admin panels, forms, landing pages. Always use the App Router (not Pages Router) with server-side rendering. Deploy on Deno Deploy.

### Deploying a Next.js app to Deno Deploy
Use the `nextjs` framework preset when creating the app. It automatically configures the correct build settings, entrypoint, and runtime mode:
```bash
deno deploy create --framework-preset nextjs --org <your-org> --app <your-app> --source local
```
For subsequent deploys after the app is created, just run `deno deploy` from your project directory. All dashboard options have CLI flag equivalents, so you can use them in CI pipelines or scripts without any interactive prompts.

- **shadcn/ui** (https://ui.shadcn.com/) and **AI SDK Elements** (https://elements.ai-sdk.dev/) for UI design.
- **Search agent-skill registries before building UI from scratch.** Before starting a non-trivial frontend, check whether someone has already published a skill that fits. Two registries worth searching every time:
  - https://github.com/anthropics/skills
  - https://github.com/vercel-labs/agent-skills

  Use `gh search code` or browse the repos directly to find skills covering the UI pattern you need (dashboards, forms, charts, chat UIs, landing pages, etc.). If a relevant skill exists, acquire it (learn it if already available, otherwise install it from the community registry first) and follow its conventions instead of inventing your own. A pre-existing skill encodes design decisions, accessibility, and component choices that would otherwise take you hours to rediscover. Only build from scratch if nothing matches.
