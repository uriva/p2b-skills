# Cloudflare Quick Tunnels (TryCloudflare) Reference

Reference for using **Cloudflare Quick Tunnels** (`https://try.cloudflare.com/`) to expose local development servers to the public internet for webhook testing, E2E verification, and temporary previews.

- **Primary Reference:** `https://try.cloudflare.com/`
- **Developer Documentation:** `https://developers.cloudflare.com/tunnel/get-started/#quick-tunnels-development`

---

## 1. What is Cloudflare Quick Tunnels?

Cloudflare Quick Tunnels (TryCloudflare) allows you to turn any local server on `localhost:<port>` into a public, encrypted URL on Cloudflare's global edge network using a single command:

```bash
cloudflared tunnel --url http://localhost:8000
```

### Key Capabilities & Architecture:
- **Zero Configuration:** No Cloudflare account, no login, no API token, no domain, and no DNS setup required.
- **Zero Inbound Ports (Outbound-Only):** Opens an outbound-only connection to Cloudflare's nearest edge location. Works seamlessly behind NAT, firewalls, and cloud VM/sandbox environments (such as Modal sandboxes or dev containers) where inbound ports cannot be opened.
- **Automatic TLS & Edge Security:** Traffic is encrypted with automatic HTTPS and protected by Cloudflare's edge DDoS mitigation.
- **Structured JSON Output for Coding Agents:** Supports `--output json` on stdout (`{"level":"info","message":"https://<subdomain>.trycloudflare.com","time":"..."}`), allowing automated scripts and agents to extract the generated tunnel URL cleanly without fragile regex log parsing.
- **Ephemeral by Design:** The tunnel dies with the process. When `cloudflared` exits, the public URL terminates immediately with nothing left to clean up or revoke.

---

## 2. When to Use Quick Tunnels (Agent Workflows)

Quick Tunnels solve several critical development and verification challenges for coder agents:

### A. Local Webhook Testing Before Deployment (CRITICAL SPEED ADVANTAGE)
When building integrations that receive incoming webhooks (Stripe, GitHub, Shopify, Supergreen WhatsApp/Facebook, Telegram bot webhooks, Calendly, Make, etc.):
- **Without a tunnel:** You must commit, push to GitHub, wait for CI to deploy to Deno Deploy, configure environment variables, and trigger the webhook against the live service. If payload parsing or signature validation fails, you must repeat the entire push-and-deploy cycle to debug.
- **With a Quick Tunnel:** Start the local server on the VM (`http://localhost:8000`), open a Quick Tunnel, register the generated `https://<random>.trycloudflare.com` URL as the webhook callback with the external service, trigger a test event, and inspect incoming requests and logs directly in your local terminal. Once verified, push to GitHub for production CI deployment.

### B. Pre-Deployment E2E and Headless Browser Verification
The coder skill mandates verifying functionality before declaring completion and forbids sharing raw VM IP addresses. Because VMs lack public inbound open ports, external test harnesses, headless browsers (e.g. `agent-browser`), or screenshot services cannot access `http://localhost:8000` directly:
- Starting a Quick Tunnel provides a live public HTTPS address that external browsers or screenshot tools can immediately hit to verify UI rendering, responsiveness, and API endpoints before committing code to git.

### C. Temporary Interactive Previews
When a user asks for a quick preview or when demonstrating prototype functionality during an active chat turn, an ephemeral Quick Tunnel can provide an immediate clickable link.

---

## 3. Command Reference & Script Patterns

### Basic Invocations
```bash
# Start a tunnel pointing to a local HTTP port
cloudflared tunnel --url http://localhost:8000

# Start with structured JSON output (recommended for agents and scripts)
cloudflared tunnel --url http://localhost:8000 --output json
```

### Automated Background Pattern on the VM
In non-interactive VM scripts, run the server and tunnel in the background, extract the assigned URL from the initial JSON logs, perform the tests, and tear down when finished:

```bash
# 1. Start the local server in the background
deno run --allow-net server.ts &
SERVER_PID=$!

# 2. Start the tunnel in the background with JSON output redirected to a log file
cloudflared tunnel --url http://localhost:8000 --output json > /tmp/tunnel.log 2>&1 &
TUNNEL_PID=$!

# 3. Wait for the tunnel URL to appear in the log (typically ~3 seconds)
sleep 3
TUNNEL_URL=$(grep -o 'https://[a-zA-Z0-9-]*\.trycloudflare\.com' /tmp/tunnel.log | head -n 1)
echo "Tunnel public URL: $TUNNEL_URL"

# 4. Perform your tests (e.g., test curl, register as webhook callback, run browser check)
curl -s "$TUNNEL_URL/health"

# 5. Clean up when testing completes
kill $TUNNEL_PID $SERVER_PID
```

### Installing `cloudflared` if Missing
If `cloudflared` is not pre-installed in the workspace, download the standalone Linux binary:
```bash
curl -fsSL https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64 -o /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared
```
(On macOS: `brew install cloudflared`; on Windows: `winget install Cloudflare.cloudflared`).

---

## 4. Limitations & Critical Anti-Patterns

- **TESTING & PREVIEWS ONLY — NEVER FOR PRODUCTION HOSTING (CRITICAL):**
  - Quick Tunnels are explicitly intended for testing and development.
  - **Hard Request Limits:** Quick Tunnels are subject to a hard limit of 200 concurrent in-flight requests. Exceeding this limit returns HTTP `429 Too Many Requests`.
  - **No Server-Sent Events (SSE):** Quick Tunnels do not support SSE streaming.
  - **Ephemeral Domains:** The random subdomain changes every time `cloudflared` restarts.
  - **No SLA:** Cloudflare provides no uptime SLA for TryCloudflare.
  - **Cardinal Rule:** Never use a Quick Tunnel as a permanent hosting solution. The VM is an ephemeral workspace. All production user-facing applications, APIs, and webhooks MUST be deployed to Deno Deploy via GitHub Actions CI (see `vm-and-secrets.md` and `planning-and-design.md`).
- **Always Clean Up Background Processes:** Do not leave background `cloudflared` processes running when you are done testing. Terminate the process to free resources and close the tunnel.
- **Never Put Secrets in Public Tunnel URLs:** Keep all tokens and secrets in HTTP headers or environment variables, never in URL query parameters.
