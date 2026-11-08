import { githubHeaders, instructionFileBlock, readGithubFile } from "../scripts/github.ss"

rendersFoundFile = () => {
  block = instructionFileBlock({ label: "AGENTS.md", read: { success: true, result: "do the thing", error: "" } })
  assert({ condition: stringIncludes({ haystack: block, needle: "AGENTS.md" }).result, message: "expected label in rendered block" })
  assert({ condition: stringIncludes({ haystack: block, needle: "do the thing" }).result, message: "expected file content in rendered block" })
  return true
}

omitsMissingFile = () => {
  block = instructionFileBlock({ label: "CLAUDE.md", read: { success: false, result: "", error: "GITHUB_READ_FILE_ERROR: 404" } })
  assert({ condition: block == "", message: "expected missing file to render as empty string" })
  return true
}

mockGithubHttpRequestRequiringUserAgent = (host: string, method: string, path: string, headers: { Authorization: string, Accept: string }): { status: number, body: string } => {
  serialized = jsonStringify({ value: headers })
  hasUa = stringIncludes({ haystack: serialized.text, needle: "User-Agent" }).result
  return hasUa ? { status: 200, body: "file-body" } : { status: 403, body: "Request forbidden by administrative rules. Please make sure your request has a User-Agent header" }
}

includesUserAgentInHeadersAndReadGithubFile = () => {
  hdrs = githubHeaders({ githubToken: "tok_123" })
  serializedHdrs = jsonStringify({ value: hdrs })
  assert({ condition: stringIncludes({ haystack: serializedHdrs.text, needle: "User-Agent" }).result, message: "expected User-Agent in githubHeaders" })
  f = override(readGithubFile, { httpRequest: mockGithubHttpRequestRequiringUserAgent })
  res = f({ githubToken: "tok_123", owner: "acme", repo: "demo", path: "README.md", ref: "main" })
  assert({ condition: res.success == true, message: "expected readGithubFile to send User-Agent header and succeed" })
  assert({ condition: res.result == "file-body", message: "expected file body" })
  return true
}
