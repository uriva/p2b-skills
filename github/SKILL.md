---
name: github
description: Read and edit GitHub repositories through the GitHub REST API using a bot's GITHUB_TOKEN.
---

# GitHub Skill

Use this skill to read and edit GitHub repositories without creating a VM or
cloning the repository.

Pass the configured GitHub token secret as `githubToken` through
`secretMapping`. Usually this should be:

```json
{ "githubToken": "GITHUB_TOKEN" }
```

The token must have access to the repository and must allow requests to
`api.github.com`.

## Tools

- `readGithubFile`: reads a file from a branch or ref.
- `writeGithubFile`: commits a full file replacement using the Git Data API.
- `patchGithubFile`: reads a file, performs an exact string replacement, and
  commits the result using the Git Data API.
- `createGithubIssue`: creates a GitHub issue.
- `addGithubIssueComment`: adds a comment to an issue or pull request.
- `createGithubPullRequest`: creates a pull request.
- `patchTextForTest`: pure helper used for testing patch semantics.

## Editing Rules

Prefer `patchGithubFile` for small changes. It follows OpenCode-style safe
editing semantics:

- `searchText` must exactly match existing file content.
- If `replaceAll` is `false`, `searchText` must occur exactly once.
- If `searchText` occurs zero times, the tool returns `SEARCH_TEXT_NOT_FOUND`.
- If `searchText` occurs multiple times and `replaceAll` is `false`, the tool
  returns `SEARCH_TEXT_NOT_UNIQUE`.
- Set `replaceAll` to `true` only when every occurrence should change.

Use `writeGithubFile` only when creating or replacing a whole file is clearer
than a precise patch.

Use `createGithubIssue`, `addGithubIssueComment`, and `createGithubPullRequest`
for project-management tasks instead of shelling out to `curl`. This avoids VM
state issues and command-length limits for long issue/comment bodies.

Pass `issueNumber` as a string, for example `"11"`.
