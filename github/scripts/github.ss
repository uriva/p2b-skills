authHeader = (githubToken: string): string => {
  header = stringConcat({ parts: ["Bearer ", githubToken] })
  return header.result
}

githubHeaders = (githubToken: string) => {
  return { Authorization: authHeader(githubToken), Accept: "application/vnd.github+json", "X-GitHub-Api-Version": "2022-11-28" }
}

repoPath = (owner: string, repo: string, suffix: string): string => {
  path = stringConcat({ parts: ["/repos/", owner, "/", repo, suffix] })
  return path.result
}

branchRefPath = (owner: string, repo: string, branch: string): string => {
  encodedBranch = urlEncode(branch)
  suffix = stringConcat({ parts: ["/git/refs/heads/", encodedBranch.encoded] })
  return repoPath(owner, repo, suffix.result)
}

branchRefPathForTest = (owner: string, repo: string, branch: string): string => {
  return branchRefPath(owner, repo, branch)
}

readGithubFile = (githubToken: string, owner: string, repo: string, path: string, ref: string): { success: boolean, result: string, error: string } => {
  encodedRef = urlEncode(ref)
  suffix = stringConcat({ parts: ["/contents/", path, "?ref=", encodedRef.encoded] })
  requestPath = repoPath(owner, repo, suffix.result)
  res = httpRequest({ host: "api.github.com", method: "GET", path: requestPath, headers: { Authorization: authHeader(githubToken), Accept: "application/vnd.github.raw+json", "X-GitHub-Api-Version": "2022-11-28" } })
  error = stringConcat({ parts: ["GITHUB_READ_FILE_ERROR: ", res.body] })
  return res.status == 200 ? { success: true, result: res.body, error: "" } : { success: false, result: "", error: error.result }
}

instructionFileBlock = (label: string, read: { success: boolean, result: string, error: string }): string => {
  shown = stringConcat({ parts: ["\n===== ", label, " =====\n", read.result, "\n"] })
  return read.success ? shown.result : ""
}

repoInstructions = (githubToken: string, owner: string, repo: string, ref: string): { success: boolean, result: string, error: string } => {
  agents = readGithubFile(githubToken, owner, repo, "AGENTS.md", ref)
  claude = readGithubFile(githubToken, owner, repo, "CLAUDE.md", ref)
  copilot = readGithubFile(githubToken, owner, repo, ".github/copilot-instructions.md", ref)
  cursor = readGithubFile(githubToken, owner, repo, ".cursorrules", ref)
  gemini = readGithubFile(githubToken, owner, repo, "GEMINI.md", ref)
  windsurf = readGithubFile(githubToken, owner, repo, ".windsurfrules", ref)
  combined = stringConcat({ parts: [instructionFileBlock("AGENTS.md", agents), instructionFileBlock("CLAUDE.md", claude), instructionFileBlock(".github/copilot-instructions.md", copilot), instructionFileBlock(".cursorrules", cursor), instructionFileBlock("GEMINI.md", gemini), instructionFileBlock(".windsurfrules", windsurf)] })
  anyFound = agents.success ? true : (claude.success ? true : (copilot.success ? true : (cursor.success ? true : (gemini.success ? true : windsurf.success))))
  emptyError = stringConcat({ parts: ["NO_INSTRUCTION_FILES_FOUND: none of AGENTS.md, CLAUDE.md, .github/copilot-instructions.md, .cursorrules, GEMINI.md, .windsurfrules exist in ", owner, "/", repo, " at ref \"", ref, "\". Proceed, but infer conventions from the codebase."] })
  return anyFound ? { success: true, result: combined.result, error: "" } : { success: false, result: "", error: emptyError.result }
}

patchTextForTest = (content: string, searchText: string, replaceText: string, replaceAll: boolean): { success: boolean, result: string, error: string, count: number } => {
  replaced = stringReplace({ haystack: content, needle: searchText, replacement: replaceText, all: replaceAll })
  notFound = replaced.count == 0
  notUnique = replaceAll ? false : replaced.count > 1
  error = notFound ? "SEARCH_TEXT_NOT_FOUND" : (notUnique ? "SEARCH_TEXT_NOT_UNIQUE" : "")
  result = error == "" ? replaced.result : content
  return error == "" ? { success: true, result, error: "", count: replaced.count } : { success: false, result, error, count: replaced.count }
}

writeGithubFile = (githubToken: string, owner: string, repo: string, branch: string, path: string, content: string, commitMessage: string): { success: boolean, result: string, error: string } => {
  refPath = branchRefPath(owner, repo, branch)
  refRes = httpRequest({ host: "api.github.com", method: "GET", path: refPath, headers: githubHeaders(githubToken) })
  refOk = refRes.status == 200
  
  // If the ref is not found (404), fallback to the Contents API (creates file in empty repo)
  urlSafe = refOk ? { encoded: "" } : base64urlEncode({ text: content })
  withPlus = refOk ? { result: "" } : stringReplace({ haystack: urlSafe.encoded, needle: "-", replacement: "+", all: true })
  withSlash = refOk ? { result: "" } : stringReplace({ haystack: withPlus.result, needle: "_", replacement: "/", all: true })
  fallbackBody = refOk ? { text: "" } : jsonStringify({ value: { message: commitMessage, content: withSlash.result, branch: branch } })
  fallbackPath = refOk ? "" : stringConcat({ parts: ["/contents/", path] }).result
  fallbackRes = refOk ? { status: 0, body: "" } : httpRequest({ host: "api.github.com", method: "PUT", path: repoPath(owner, repo, fallbackPath), headers: githubHeaders(githubToken), body: fallbackBody.text })
  fallbackOk = fallbackRes.status == 201
  fallbackParsed = fallbackOk ? jsonParse(fallbackRes.body) : { value: { content: { html_url: "" } } }
  
  refParsed = refOk ? jsonParse(refRes.body) : { value: { object: { sha: "" } } }
  headSha = refParsed.value.object.sha

  commitPath = repoPath(owner, repo, stringConcat({ parts: ["/git/commits/", headSha] }).result)
  commitRes = refOk ? httpRequest({ host: "api.github.com", method: "GET", path: commitPath, headers: githubHeaders(githubToken) }) : { status: 0, body: refRes.body }
  commitOk = commitRes.status == 200
  commitParsed = commitOk ? jsonParse(commitRes.body) : { value: { tree: { sha: "" } } }
  baseTree = commitParsed.value.tree.sha

  treeBody = jsonStringify({ value: { base_tree: baseTree, tree: [{ path: path, mode: "100644", type: "blob", content: content }] } })
  treePath = repoPath(owner, repo, "/git/trees")
  treeRes = commitOk ? httpRequest({ host: "api.github.com", method: "POST", path: treePath, headers: githubHeaders(githubToken), body: treeBody.text }) : { status: 0, body: commitRes.body }
  treeOk = treeRes.status == 201
  treeParsed = treeOk ? jsonParse(treeRes.body) : { value: { sha: "" } }

  newCommitBody = jsonStringify({ value: { message: commitMessage, tree: treeParsed.value.sha, parents: [headSha] } })
  newCommitPath = repoPath(owner, repo, "/git/commits")
  newCommitRes = treeOk ? httpRequest({ host: "api.github.com", method: "POST", path: newCommitPath, headers: githubHeaders(githubToken), body: newCommitBody.text }) : { status: 0, body: treeRes.body }
  newCommitOk = newCommitRes.status == 201
  newCommitParsed = newCommitOk ? jsonParse(newCommitRes.body) : { value: { sha: "", html_url: "" } }

  updateBody = jsonStringify({ value: { sha: newCommitParsed.value.sha, force: false } })
  updateRes = newCommitOk ? httpRequest({ host: "api.github.com", method: "PATCH", path: refPath, headers: githubHeaders(githubToken), body: updateBody.text }) : { status: 0, body: newCommitRes.body }
  errorStep = refOk ? (commitOk ? (treeOk ? (newCommitOk ? "update_ref" : "create_commit") : "create_tree") : "get_commit") : "get_ref"
  errorBody = stringConcat({ parts: ["GITHUB_WRITE_FILE_ERROR ", errorStep, ": ", updateRes.body] })
  return refOk ? (updateRes.status == 200 ? { success: true, result: newCommitParsed.value.html_url, error: "" } : { success: false, result: "", error: errorBody.result }) : (fallbackOk ? { success: true, result: fallbackParsed.value.content.html_url, error: "" } : { success: false, result: "", error: stringConcat({ parts: ["GITHUB_WRITE_FILE_ERROR fallback_contents: ", fallbackRes.body] }).result })
}

patchGithubFile = (githubToken: string, owner: string, repo: string, branch: string, path: string, searchText: string, replaceText: string, replaceAll: boolean, commitMessage: string): { success: boolean, result: string, error: string } => {
  read = readGithubFile(githubToken, owner, repo, path, branch)
  replaced = read.success ? stringReplace({ haystack: read.result, needle: searchText, replacement: replaceText, all: replaceAll }) : { result: "", count: 0 }
  notFound = read.success ? replaced.count == 0 : false
  notUnique = read.success ? (replaceAll ? false : replaced.count > 1) : false
  patchError = notFound ? "SEARCH_TEXT_NOT_FOUND" : (notUnique ? "SEARCH_TEXT_NOT_UNIQUE" : "")
  write = read.success ? (patchError == "" ? writeGithubFile(githubToken, owner, repo, branch, path, replaced.result, commitMessage) : { success: false, result: "", error: patchError }) : { success: false, result: "", error: read.error }
  return write
}

createGithubIssue = (githubToken: string, owner: string, repo: string, title: string, body: string): { success: boolean, result: string, error: string } => {
  requestPath = repoPath(owner, repo, "/issues")
  requestBody = jsonStringify({ value: { title: title, body: body } })
  res = httpRequest({ host: "api.github.com", method: "POST", path: requestPath, headers: githubHeaders(githubToken), body: requestBody.text })
  parsed = res.status == 201 ? jsonParse(res.body) : { value: { html_url: "" } }
  error = stringConcat({ parts: ["GITHUB_CREATE_ISSUE_ERROR: ", res.body] })
  return res.status == 201 ? { success: true, result: parsed.value.html_url, error: "" } : { success: false, result: "", error: error.result }
}

addGithubIssueComment = (githubToken: string, owner: string, repo: string, issueNumber: string, body: string): { success: boolean, result: string, error: string } => {
  suffix = stringConcat({ parts: ["/issues/", issueNumber, "/comments"] })
  requestPath = repoPath(owner, repo, suffix.result)
  requestBody = jsonStringify({ value: { body: body } })
  res = httpRequest({ host: "api.github.com", method: "POST", path: requestPath, headers: githubHeaders(githubToken), body: requestBody.text })
  parsed = res.status == 201 ? jsonParse(res.body) : { value: { html_url: "" } }
  error = stringConcat({ parts: ["GITHUB_ADD_COMMENT_ERROR: ", res.body] })
  return res.status == 201 ? { success: true, result: parsed.value.html_url, error: "" } : { success: false, result: "", error: error.result }
}

createGithubPullRequest = (githubToken: string, owner: string, repo: string, title: string, body: string, head: string, base: string): { success: boolean, result: string, error: string } => {
  requestPath = repoPath(owner, repo, "/pulls")
  requestBody = jsonStringify({ value: { title: title, body: body, head: head, base: base } })
  res = httpRequest({ host: "api.github.com", method: "POST", path: requestPath, headers: githubHeaders(githubToken), body: requestBody.text })
  parsed = res.status == 201 ? jsonParse(res.body) : { value: { html_url: "" } }
  error = stringConcat({ parts: ["GITHUB_CREATE_PULL_REQUEST_ERROR: ", res.body] })
  return res.status == 201 ? { success: true, result: parsed.value.html_url, error: "" } : { success: false, result: "", error: error.result }
}

createGithubRepository = (githubToken: string, owner: string, repo_name: string, isPrivate: boolean): { success: boolean, result: string, error: string } => {
  userPath = stringConcat({ parts: ["/users/", owner] })
  userRes = httpRequest({ host: "api.github.com", method: "GET", path: userPath.result, headers: githubHeaders(githubToken) })
  userOk = userRes.status == 200
  userParsed = userOk ? jsonParse(userRes.body) : { value: { type: "" } }
  isOrg = userParsed.value.type == "Organization"
  
  createPath = isOrg ? stringConcat({ parts: ["/orgs/", owner, "/repos"] }).result : ""
  createBody = jsonStringify({ value: { name: repo_name, private: isPrivate, auto_init: true } })
  createRes = isOrg ? httpRequest({ host: "api.github.com", method: "POST", path: createPath, headers: githubHeaders(githubToken), body: createBody.text }) : { status: 0, body: "" }
  createOk = createRes.status == 201
  createParsed = createOk ? jsonParse(createRes.body) : { value: { html_url: "" } }
  
  errorMsg = isOrg ? stringConcat({ parts: ["GITHUB_CREATE_REPOSITORY_ERROR: ", createRes.body] }).result : stringConcat({ parts: ["PERSONAL_ACCOUNT_RESTRICTION: GitHub Apps cannot programmatically create repositories on personal accounts like ", owner, ". Please create the repository manually at https://github.com/new, name it \"", repo_name, "\", set it to Private, and check \"Add a README file\" so it is initialized."] }).result
  
  return createOk ? { success: true, result: createParsed.value.html_url, error: "" } : { success: false, result: "", error: errorMsg }
}
