denoDeployHeaders = (denoDeployToken: string) => {
  bearer = stringConcat({ parts: ["Bearer ", denoDeployToken] })
  return { Authorization: bearer.result, "Content-Type": "application/json" }
}

appPath = (appSlug: string, suffix: string): string => {
  path = stringConcat({ parts: ["/v2/apps/", appSlug, suffix] })
  return path.result
}

doc({ text: "### List Deno Deploy apps\n\nLists the applications reachable by the token's organization via the Deno Deploy REST API v2. Use this to discover app slugs instead of guessing them, and instead of the `deno deploy` CLI (which can hang on a headless VM).\n\n#### Parameters\n- `denoDeployToken` — Deno Deploy access token (a `ddo_...` token), passed via secretMapping\n\n#### Example\n```\nparams: {}\nsecretMapping: { denoDeployToken: \"DENO_DEPLOY_TOKEN\" }\n```" })

listDenoDeployApps = (denoDeployToken: string): { success: boolean, result: string, error: string } => {
  res = httpRequest({ host: "api.deno.com", method: "GET", path: "/v2/apps", headers: denoDeployHeaders(denoDeployToken) })
  error = stringConcat({ parts: ["DENO_DEPLOY_LIST_APPS_ERROR: ", res.body] })
  return res.status == 200 ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: error.result }
}

doc({ text: "### Get a Deno Deploy app\n\nFetches an app's details (including its current `env_vars`, config, and slug) via the REST API v2. Prefer this over `deno deploy env list` on a VM, which uses a streaming tRPC call with no client timeout and can hang forever.\n\n#### Parameters\n- `denoDeployToken` — Deno Deploy access token (via secretMapping)\n- `appSlug` — the application slug, e.g. `my-app`\n\n#### Example\n```\nparams: { appSlug: \"my-app\" }\nsecretMapping: { denoDeployToken: \"DENO_DEPLOY_TOKEN\" }\n```" })

getDenoDeployApp = (denoDeployToken: string, appSlug: string): { success: boolean, result: string, error: string } => {
  res = httpRequest({ host: "api.deno.com", method: "GET", path: appPath(appSlug, ""), headers: denoDeployHeaders(denoDeployToken) })
  error = stringConcat({ parts: ["DENO_DEPLOY_GET_APP_ERROR: ", res.body] })
  return res.status == 200 ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: error.result }
}

doc({ text: "### Create a Deno Deploy app\n\nCreates a new application in the token's organization via the REST API v2. The org is derived from the token, so no `--org` is needed. Prefer this over `deno deploy create` on a VM.\n\n#### Parameters\n- `denoDeployToken` — Deno Deploy access token (via secretMapping)\n- `appSlug` — desired app slug (3–32 chars, lowercase letters/numbers/hyphens, no underscores)\n\n#### Example\n```\nparams: { appSlug: \"my-app\" }\nsecretMapping: { denoDeployToken: \"DENO_DEPLOY_TOKEN\" }\n```" })

createDenoDeployApp = (denoDeployToken: string, appSlug: string): { success: boolean, result: string, error: string } => {
  requestBody = jsonStringify({ value: { slug: appSlug } })
  res = httpRequest({ host: "api.deno.com", method: "POST", path: "/v2/apps", headers: denoDeployHeaders(denoDeployToken), body: requestBody.text })
  error = stringConcat({ parts: ["DENO_DEPLOY_CREATE_APP_ERROR: ", res.body] })
  return res.status == 200 ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: error.result }
}

doc({ text: "### Set a Deno Deploy environment variable\n\nSets (adds or updates) a single environment variable on an app via the REST API v2 `PATCH /v2/apps/{app}` endpoint, which deep-merges `env_vars` by `key`. This is the reliable, VM-less replacement for `deno deploy env add/set`, which can hang on a headless VM. For public build-time vars (e.g. `NEXT_PUBLIC_*`) pass `isSecret: false`; for credentials pass `isSecret: true` to mask the value in API responses.\n\n#### Parameters\n- `denoDeployToken` — Deno Deploy access token (via secretMapping)\n- `appSlug` — the application slug\n- `key` — env var name\n- `value` — env var value\n- `isSecret` — whether to mask the value in API responses\n\n#### Example\n```\nparams: { appSlug: \"my-app\", key: \"NEXT_PUBLIC_APP_ID\", value: \"abc123\", isSecret: false }\nsecretMapping: { denoDeployToken: \"DENO_DEPLOY_TOKEN\" }\n```" })

setDenoDeployEnvVar = (denoDeployToken: string, appSlug: string, key: string, value: string, isSecret: boolean): { success: boolean, result: string, error: string } => {
  requestBody = jsonStringify({ value: { env_vars: [{ key: key, value: value, secret: isSecret }] } })
  res = httpRequest({ host: "api.deno.com", method: "PATCH", path: appPath(appSlug, ""), headers: denoDeployHeaders(denoDeployToken), body: requestBody.text })
  error = stringConcat({ parts: ["DENO_DEPLOY_SET_ENV_ERROR: ", res.body] })
  return res.status == 200 ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: error.result }
}

doc({ text: "### Get latest Deno Deploy revision status\n\nReturns the most recent revision (deployment) for an app via the REST API v2, so you can check whether the last deploy succeeded or failed without shelling into a VM. The revision `status` is one of `skipped`, `queued`, `building`, `succeeded`, `failed`; `failure_reason` explains a failure.\n\n#### Parameters\n- `denoDeployToken` — Deno Deploy access token (via secretMapping)\n- `appSlug` — the application slug\n\n#### Example\n```\nparams: { appSlug: \"my-app\" }\nsecretMapping: { denoDeployToken: \"DENO_DEPLOY_TOKEN\" }\n```" })

latestDenoDeployRevision = (denoDeployToken: string, appSlug: string): { success: boolean, result: string, error: string } => {
  res = httpRequest({ host: "api.deno.com", method: "GET", path: appPath(appSlug, "/revisions?limit=1"), headers: denoDeployHeaders(denoDeployToken) })
  error = stringConcat({ parts: ["DENO_DEPLOY_REVISIONS_ERROR: ", res.body] })
  return res.status == 200 ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: error.result }
}
