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
  return updateRes.status == 200 ? { success: true, result: newCommitParsed.value.html_url, error: "" } : { success: false, result: "", error: errorBody.result }
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
