import { branchRefPathForTest } from "../scripts/github.ss"

encodesSlashInBranchName = () => {
  path = branchRefPathForTest({ owner: "uriva", repo: "p2b-skills", branch: "fix/github-write" })
  assert({ condition: path == "/repos/uriva/p2b-skills/git/ref/heads/fix%2Fgithub-write", message: "expected branch slash to be URL encoded" })
  return true
}
