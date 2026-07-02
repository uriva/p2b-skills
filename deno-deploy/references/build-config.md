# Deno Deploy — Build Configuration & Next.js Defaults

Read this when configuring the project's build/entrypoint for Deno Deploy, when
the Deploy compiler crashes/hangs on frontend deps, or when deciding the
framework for a new dynamic project.

## 1. Preventing CLI Loops in Headless Sandboxes (VMs)
* **The Issue:** On a headless, non-TTY sandbox VM, **any** `deno deploy`
  subcommand — `--prod`, `env list`, `logs`, `whoami`, etc. — can enter an
  infinite CPU-bound loop (99% CPU) when it needs input it cannot get
  interactively (e.g. the app/org isn't resolved yet, or auth needs a prompt).
  This is a leading cause of hung VMs and, when the same command is placed in a
  workflow, hung GitHub Actions that run for many minutes doing nothing.
* **Hard rules:**
  1. **The app is created FIRST, in CI, before any deploy** — never from the VM
     (see "Deployments are CI-only"). The canonical workflow's "Ensure app
     exists" step handles this idempotently. Deploying to a non-existent app is
     what triggers NOT_FOUND; creating first is what makes deploys
     deterministic.
  2. **Every `deno deploy` invocation — in CI or the occasional VM-side
     `env`/`logs` inspection — MUST close stdin with `< /dev/null`, supply
     every required flag, and be wrapped in a hard `timeout`** so it fails fast
     instead of looping/hanging. The modern CLI (>= 0.0.99, what CI and current
     VMs run) DOES accept `--non-interactive` to force fast-fail on missing
     input — pass it. (Older CLIs lacked it and misparsed it as a positional;
     that is no longer the case, so do not omit it on modern CLIs.) Example:
     `timeout 120 deno deploy env list --app=<slug> --org=<org> --non-interactive < /dev/null`.
     If it hits the timeout on an *inspection* command, treat it as a real
     failure to diagnose — do not blindly retry.
  4. **`deno deploy --prod` is the exception: it hangs even on success.** The
     CLI leaks a handle after a successful deploy and never exits (see the CI
     Deploy step in the main skill). So for `--prod`, a `timeout` expiry AFTER
     the "Successfully uploaded/deployed" marker is expected and means success —
     detect the marker, do not treat the hang as a failure. This differs from
     inspection commands (`env`/`logs`), where a timeout IS a failure.
  3. **Never poll a `deno deploy` command with `check_vm_progress` in a tight
     loop.** If it hasn't returned quickly, it is almost certainly looping; stop
     it and investigate rather than spawning more polls.
* **In CI**, give the deploy job a `timeout-minutes` so a looping deploy cannot
  run for 10+ minutes (see the canonical workflow in the main skill).

## 2. Exclude Heavy Frontend Development Dependencies from Root `deno.json`
* **The Issue:** Deno Deploy's compiler analyzes all imports defined in the root `deno.json` file. Having heavy, Node-based web development tools (like Vite, PostCSS, Autoprefixer, Tailwind, or complex React components) in your root imports will crash or hang Deno Deploy's compiler during the build phase.
* **The Solution:**
  1. Compile your frontend locally into pure static assets (`web/dist`).
  2. Isolate frontend-only imports by nesting them in a local `web/deno.json` configuration file, keeping your root `deno.json` imports extremely lightweight and backend-focused (e.g., Hono, Supergreen, Zod).
  3. Declare an explicit `"exclude"` list inside both the `"exclude"` root key and the `"deploy"` key of `deno.json` to prevent Deno Deploy from scanning the frontend source code `/web/src`:
     ```json
     "exclude": ["web"],
     "deploy": {
       "project": "app-name",
       "org": "org-name",
       "entrypoint": "main.ts",
       "exclude": ["node_modules", "web"]
     }
     ```

## 3. Root Entrypoint (`main.ts`) mapping
* **The Issue:** If your backend entrypoint file is nested inside a subfolder (e.g., `src/server.ts`), Deno Deploy's compiler may fail to automatically locate the primary execution file.
* **The Solution:** Create a 1-line root-level `main.ts` file that simply boots the nested server:
  ```typescript
  import "./src/server.ts";
  ```
  And map `"entrypoint": "main.ts"` inside your `"deploy"` block.

## 4. Lockfile Synchronization
* **The Issue:** If you modify root dependencies, the `deno.lock` file can fall out of sync, causing Deno Deploy to reject the deployment with strict verification errors.
* **The Solution:** Always run `deno cache <entrypoint>` locally in your workspace to rebuild and synchronize the lockfile prior to pushing.

## 5. Next.js as the Default Framework for Dynamic Projects
* **Standard Decision:** For all new project architectures that require dynamic content, blog posts, documentation pages, dynamically generated specifications (like `/llms.txt`), dynamic OpenGraph (OG) image generation, or search engine indexing (SEO), **Next.js must be configured as the default framework**.
* **Reasoning:** Next.js provides native Server-Side Rendering (SSR) capabilities. Unlike standard React Single-Page Apps (SPAs) which render as a blank HTML shell requiring client-side JS hydration, Next.js dynamic endpoints deliver fully populated, text-ready HTML directly in the raw response. This ensures 100% readability and immediate indexing by lightweight web crawlers, search engines, and LLM scrappers that cannot execute client-side JavaScript.
