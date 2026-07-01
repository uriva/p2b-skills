import { createGithubRepository } from "../scripts/github.ss"

mockHttpRequest = (host, method, path) => {
  isUsers = stringIncludes({ haystack: path, needle: "/users/test-org" }).result
  isPostRepos = stringIncludes({ haystack: path, needle: "/orgs/test-org/repos" }).result
  status = isUsers ? 200 : (isPostRepos ? 401 : 200)
  resBody = isUsers ? "{\"type\":\"Organization\"}" : (isPostRepos ? "{\"message\":\"Bad credentials\"}" : "{}")
  return { status: status, body: resBody }
}

failsWithInvalidToken = () => {
  f = override(createGithubRepository, { httpRequest: mockHttpRequest })
  res = f({ githubToken: "invalid_token_test", owner: "test-org", repo_name: "test-repo-creation-failure", isPrivate: true })
  assert({ condition: res.success == false, message: "expected failure with invalid token" })
  assert({ condition: stringIncludes({ haystack: res.error, needle: "GITHUB_CREATE_REPOSITORY_ERROR" }).result, message: "expected GITHUB_CREATE_REPOSITORY_ERROR in the error" })
  return true
}
