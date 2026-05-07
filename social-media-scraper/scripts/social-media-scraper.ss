doc({ text: "### Query Facebook Posts\n\nSearch or get Facebook posts via RapidAPI. Can search general posts, search posts in a group, or get all posts from a group.\n\n#### Parameters\n- `rapidApiKey` — Your RapidAPI key (pass via secretMapping, e.g. `{ rapidApiKey: \"RAPIDAPI_KEY\" }`)\n- `query` — Search query for posts (empty string to omit)\n- `groupId` — Facebook group ID (empty string to omit)\n- `sortingOrder` — Sorting order for group posts, e.g. `CHRONOLOGICAL` (ignored when groupId is empty)\n\n#### Example\n```\nparams: { query: \"deno\", groupId: \"\", sortingOrder: \"\" }\nsecretMapping: { rapidApiKey: \"RAPIDAPI_KEY\" }\n```" })

facebookPosts = (rapidApiKey: string, query: string, groupId: string, sortingOrder: string): { success: boolean, result: string, error: string } => {
  hasQuery = query != ""
  hasGroupId = groupId != ""
  isMissing = hasQuery ? false : (hasGroupId ? false : true)

  searchPath = stringConcat({ parts: ["/search/posts?query=", urlEncode({ text: query }).encoded] })
  groupPath = stringConcat({ parts: ["/group/posts?group_id=", groupId, "&sorting_order=", sortingOrder] })
  searchGroupPath = stringConcat({ parts: ["/search/groups_posts?query=", urlEncode({ text: query }).encoded, "&group_id=", groupId] })

  path = hasGroupId ? (hasQuery ? searchGroupPath.result : groupPath.result) : (hasQuery ? searchPath.result : "")

  res = isMissing
    ? { status: 400, body: "Error: Either query or group_id must be provided" }
    : httpRequest({ host: "facebook-scraper3.p.rapidapi.com", method: "GET", path: path, headers: { "x-rapidapi-key": rapidApiKey, "x-rapidapi-host": "facebook-scraper3.p.rapidapi.com" } })

  isOk = res.status == 200
  errorMsg = stringConcat({ parts: ["API error: ", jsonStringify({ value: res.status }).text, " ", res.body] })

  return isOk ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorMsg.result }
}

doc({ text: "### Start LinkedIn Profile Scrape\n\nStart a LinkedIn profile scrape via Bright Data. Pass up to 10 LinkedIn profile URLs. Returns either an immediate result or a `snapshot_id` that can be polled with `getLinkedInProfileSnapshot`.\n\n#### Parameters\n- `brightDataToken` — Your Bright Data API token (pass via secretMapping)\n- `urls` — Array of LinkedIn profile URLs, e.g. `[\"https://www.linkedin.com/in/uriv\"]`\n\n#### Example\n```\nparams: { urls: [\"https://www.linkedin.com/in/uriv\"] }\nsecretMapping: { brightDataToken: \"BRIGHTDATA_TOKEN\" }\n```" })

isLinkedInUrl = (url: string): boolean => {
  matched = stringRegex({ text: url, pattern: "^https://(www\.)?linkedin\.com/in/[a-zA-Z0-9_-]+/?$" })
  return matched.match
}

startLinkedInProfileScrape = (brightDataToken: string, urls: string[]): { success: boolean, result: string, error: string } => {
  validUrls = filter(isLinkedInUrl, urls)
  allValid = validUrls.length == urls.length
  tooMany = urls.length > 10
  notAllValid = allValid ? false : true

  items = map(toScrapeItem, urls)
  body = jsonStringify({ value: items })
  authHeader = stringConcat({ parts: ["Bearer ", brightDataToken] })

  res = notAllValid
    ? { status: 400, body: stringConcat({ parts: ["Invalid LinkedIn URLs: ", jsonStringify({ value: urls }).text] }).result }
    : tooMany
    ? { status: 400, body: "Max 10 URLs at a time" }
    : httpRequest({ host: "api.brightdata.com", method: "POST", path: "/datasets/v3/scrape?dataset_id=gd_l1viktl72bvl7bjuj0&include_errors=true", headers: { "Authorization": authHeader.result, "Content-Type": "application/json" }, body: body.text })

  isOk = res.status == 200
  errorMsg = stringConcat({ parts: ["API error: ", jsonStringify({ value: res.status }).text, " ", res.body] })

  return isOk ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: errorMsg.result }
}

doc({ text: "### Get LinkedIn Snapshot\n\nFetch the status and result of a pending Bright Data LinkedIn snapshot. If the snapshot is ready (`status == \"ready\"`), returns the scraped profile data. If it's still running, returns the current status. If it failed, returns an error.\n\n#### Parameters\n- `brightDataToken` — Your Bright Data API token (pass via secretMapping)\n- `snapshotId` — The snapshot ID from `startLinkedInProfileScrape`\n\n#### Example\n```\nparams: { snapshotId: \"s_abc123\" }\nsecretMapping: { brightDataToken: \"BRIGHTDATA_TOKEN\" }\n```" })

getLinkedInProfileSnapshot = (brightDataToken: string, snapshotId: string): { success: boolean, result: string, error: string } => {
  authHeader = stringConcat({ parts: ["Bearer ", brightDataToken] })
  progressPath = stringConcat({ parts: ["/datasets/v3/progress/", snapshotId] })

  progressRes = httpRequest({ host: "api.brightdata.com", method: "GET", path: progressPath.result, headers: { "Authorization": authHeader.result } })

  isOk = progressRes.status == 200
  progressError = stringConcat({ parts: ["Progress check error: ", jsonStringify({ value: progressRes.status }).text] })

  parsed = isOk ? jsonParse({ text: progressRes.body }) : { value: { status: "" } }
  status = parsed.value.status

  isReady = status == "ready"
  isFailed = status == "failed"

  downloadPath = stringConcat({ parts: ["/datasets/v3/snapshot/", snapshotId, "?format=json"] })
  downloadRes = isReady
    ? httpRequest({ host: "api.brightdata.com", method: "GET", path: downloadPath.result, headers: { "Authorization": authHeader.result } })
    : { status: 0, body: "" }

  downloadOk = downloadRes.status == 200

  result = isFailed
    ? "Snapshot collection failed"
    : isReady
    ? (downloadOk ? downloadRes.body : stringConcat({ parts: ["Download error: ", jsonStringify({ value: downloadRes.status }).text] }).result)
    : stringConcat({ parts: ["Snapshot status: ", status] }).result

  return isOk ? { success: true, result: result, error: "" } : { success: false, result: "", error: progressError.result }
}
