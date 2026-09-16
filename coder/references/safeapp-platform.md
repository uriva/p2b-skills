# SafeApp Platform: Agent-Native Full-Stack Architecture

This guide explains **SafeApp** (`https://safeapp.uriva.deno.net`), its architecture, advantages, disadvantages, and the exact decision matrix for when to choose it over a traditional GitHub/Next.js/VM stack.

- **Primary Platform Spec:** `https://safeapp.uriva.deno.net/llms.txt`
- **Safescript Language Spec:** `https://safescript.dev/llms.txt`

---

## 1. What is SafeApp?

SafeApp is an agent-native, file-free, and git-free application platform where **policy derives placement**.

Instead of editing files on disk and managing git repositories, agents build and deploy applications via structured REST API calls (`/api/v1/apps`). Application logic is written in **safescript** (a pure, functional language with decidable compile-time data-flow signatures). SafeApp statically analyzes the AST:
- Code accessing vaulted secrets or server capabilities is automatically placed on the **server**.
- UI and presentation nodes (`render`, View ADT) are placed on the **client**.
- The RPC bridge between client and server is generated automatically.
- Infrastructure primitives (Realtime Relational DB, Zero-Latency Deno KV, and GCP Cloud Tasks) are automatically provisioned upon app creation.

---

## 2. Advantages of SafeApp

1. **Zero-Setup & Extreme Agent Speed:**
   - No VM provisioning, no Docker container builds, no `npm install` wait times, and no dependency version conflicts.
   - Code updates and branch revisions take milliseconds to compile and serve live.
   - Primitives (relational database, KV, task queue) are allocated instantly with zero infrastructure configuration.

2. **Provable Security & Secret Leak Prevention:**
   - Secrets are stored in a write-only server vault with explicit host allowlists (e.g. `allowedHosts: ["api.stripe.com"]`).
   - The placement compiler mathematically proves that no secret reaches the client bundle or an unauthorized network host.
   - Placing a secret on the client requires explicit capability permission (`can_access_secrets`).

3. **Autonomous, Review-Free Policy Merging:**
   - SafeApp compares static signatures before and after changes.
   - If an agent's feature branch introduces no new secret leaks or unallowlisted network sinks, the branch merges to `main` automatically without human gatekeeping.

4. **Headless Agent Authentication (Zero Email Required):**
   - End-users can log in to apps via email magic codes.
   - **Crucially for agents:** Agents can mint authenticated app user tokens programmatically via `POST /api/v1/apps/:appId/auth/token` without needing an email inbox.
   - Browsers can open the app with `?auth_token=<token>`, auto-hydrate session storage, and execute authenticated server RPC calls immediately.

5. **Isomorphic SSR & Realtime Client Reactivity:**
   - Server-side renders crawlable HTML out of the box with state hydration.
   - Client bundle executes lightweight reactive DOM updates via delegated event handlers.

---

## 3. Disadvantages of SafeApp

1. **Language Scope (Safescript):**
   - Application logic must be written in **safescript** rather than arbitrary JavaScript/TypeScript.
   - Safescript is intentionally functional and non-Turing-complete (no unbounded loops, no `while`/`for` loops, no arbitrary `class` inheritance, no raw `eval`).
   - You cannot import heavy arbitrary npm libraries directly into safescript functions.

2. **No Traditional Git Repo on Disk:**
   - SafeApp does not use `.git` trees or files on disk. Code lives in an entity store.
   - If a client or user specifically demands a standard GitHub repository they can `git clone` to their local machine and run `npm run dev`, SafeApp is not a traditional file-based repository.

3. **View Structure:**
   - UIs are constructed via a structured View ADT (`{ tag, attrs, children, on }`) rather than raw JSX with arbitrary custom React hook lifecycles.

---

## 4. Decision Matrix: When to Choose SafeApp vs Traditional Stack

| Requirement / Context | Recommendation | Rationale |
| :--- | :--- | :--- |
| **Autonomous agent builds an internal tool, CRM, dashboard, or data service quickly** | **SafeApp** | Zero VM friction, instant deploy, built-in database, KV, and queues without configuring external services. |
| **High security requirements with vaulted API secrets and strict egress allowlists** | **SafeApp** | Provable placement guarantees secrets never leak to browser bundles or untrusted hosts. |
| **Agent needs to test the app in a headless browser with authentication** | **SafeApp** | Headless token minting (`/auth/token`) allows browser entry without an email inbox. |
| **Multi-branch rapid iteration with automated policy-gated merges** | **SafeApp** | Mathematical zero-diff security gate allows safe autonomous branch merging without human review. |
| **User explicitly asks for a GitHub repo to clone and run locally with `npm run dev`** | **Traditional Stack** | Traditional GitHub repo + Next.js + Deno Deploy fits traditional human developer workflows. |
| **App requires heavy third-party npm client packages (Three.js, WebGL, Canvas games, etc.)** | **Traditional Stack** | Next.js / Vite allows bundling arbitrary npm packages that require deep browser DOM hooks. |
| **App requires custom Docker containers, Python/Rust microservices, or long background daemons** | **Traditional Stack** | Modal VMs or container hosting support arbitrary system runtimes. |

---

## 5. Authentication, InstantDB Permissions & Schema Modifications

### A. Preview Route vs. Application Auth
- `/preview/:appId/:branch` is the live web host for the app. It is **intentionally public** to serve end-users, clients, and anonymous visitors without requiring a SafeApp developer account.
- **Access control belongs in the application code:**
  - `initialState`: Never return confidential multi-tenant or CRM data for anonymous visitors. Initialize with `{ user: null, leads: [], view: "login" }`.
  - `render`: Display a Login screen (`_ctx.auth.sendMagicCode` / `signInWithMagicCode`) when `state.user == null`.
  - Server Functions: Guard sensitive operations with `if (ctx.auth.user == null) { return { error: "Unauthorized" }; }`.

### B. InstantDB Permissions & The Admin Token Bypass (CRITICAL)
- **Why incognito / curl saw data:** Server functions and SSR run with `INSTANT_ADMIN_TOKEN`. **Admin privileges bypass InstantDB permission rules completely.**
- If `initialState` or a server function queries `dbQuery` without checking `ctx.auth.user`, InstantDB returns all records because it executes as Admin, and SSR embeds them into static HTML and `__SAFEAPP_STATE__`!
- InstantDB permissions (CEL expressions like `"allow": { "view": "auth.id != null" }`) protect **direct client queries**, not unauthenticated server queries running with admin tokens.

### C. Modifying Permissions (Rules) and Schema
Agents can modify their app's InstantDB database rules and schema directly via REST API:
- **Inspect Permissions:** `GET /api/v1/apps/:appId/resources/database/rules` (or `/perms`)
- **Update Permissions:** `POST /api/v1/apps/:appId/resources/database/rules` (or `/perms`)
  ```json
  {
    "rules": {
      "leads": {
        "allow": {
          "view": "auth.id != null",
          "create": "auth.id != null",
          "update": "auth.id in data.ref('owner.id')",
          "delete": "auth.id in data.ref('owner.id')"
        }
      }
    }
  }
  ```
- **Inspect Schema:** `GET /api/v1/apps/:appId/resources/database/schema`
- **Update Schema:** `POST /api/v1/apps/:appId/resources/database/schema`
  ```json
  {
    "schema": {
      "leads": {
        "name": "string",
        "status": "string",
        "ownerId": "string"
      }
    }
  }
  ```
- **Via CLI (if local files exist):**
  Run `npx instant-cli push perms --yes` (using `instant.perms.ts`) or `npx instant-cli push schema --yes` (using `instant.schema.ts`).

---

## 6. Quick API Cheat Sheet for Agents

- **Documentation:** Fetch `https://safeapp.uriva.deno.net/llms.txt` for live endpoint schemas.
- **Scaffold App:** `POST https://safeapp.uriva.deno.net/api/v1/apps` with `{ "id": "my-app", "name": "My App" }`.
- **Deploy Code:** `POST https://safeapp.uriva.deno.net/api/v1/apps/:appId/branches/:branch/functions` with `{ "updates": { ... } }`.
- **Update DB Rules:** `POST https://safeapp.uriva.deno.net/api/v1/apps/:appId/resources/database/rules` with `{ "rules": { ... } }`.
- **Mint Auth Token for Testing:** `POST https://safeapp.uriva.deno.net/api/v1/apps/:appId/auth/token` with `{ "email": "agent@system.local" }`.
- **Open in Browser:** `https://safeapp.uriva.deno.net/preview/:appId/:branch?auth_token=<token>`.
- **Merge Branch:** `POST https://safeapp.uriva.deno.net/api/v1/apps/:appId/branches/:branch/merge` with `{ "targetBranch": "main" }`.
