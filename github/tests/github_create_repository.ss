import { createGithubRepository } from "../scripts/github.ss"

failsWithInvalidToken = () => {
  res = createGithubRepository({ githubToken: "invalid_token_test", repo_name: "test-repo-creation-failure" })
  assert({ condition: res.success == false, message: "expected failure with invalid token" })
  assert({ condition: stringIncludes({ haystack: res.error, needle: "GITHUB_CREATE_REPOSITORY_ERROR" }).result, message: "expected GITHUB_CREATE_REPOSITORY_ERROR in the error" })
  return true
}
