import { instructionFileBlock } from "../scripts/github.ss"

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
