---
name: github
description: Read and edit GitHub repositories through the GitHub REST API using a bot's GITHUB_TOKEN.
---

# GitHub Skill

Use this skill to read and edit GitHub repositories without creating a VM or
cloning the repository.

## Read the repo's instructions FIRST (mandatory)

Before you read, write, or patch ANY file in a repository — on your first action
against that repo, and again whenever you switch repos or branches — you MUST
call `repoInstructions` for that `owner`/`repo`/`ref` and follow what it returns.

`repoInstructions` fetches the project's agent instruction files in one call:
`AGENTS.md`, `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`,
`.cursorrules`, and `.windsurfrules`. These hold the repo's conventions,
runbooks, and "how we do X here" knowledge. Skipping this is the most common
cause of wrong or low-quality changes — do not guess what you could have read.

If it returns `NO_INSTRUCTION_FILES_FOUND`, proceed but infer conventions from
the codebase.

Pass the configured GitHub token secret as `githubToken` through
`secretMapping`. Usually this should be:

```json
{ "githubToken": "GITHUB_TOKEN" }
```

The token must have access to the repository and must allow requests to
`api.github.com`.

## Tools

- `repoInstructions`: fetches the repo's agent instruction files (`AGENTS.md`,
  `CLAUDE.md`, `GEMINI.md`, `.github/copilot-instructions.md`, `.cursorrules`,
  `.windsurfrules`) in one call. Call this FIRST for any repo, before reading or
  editing files (see "Read the repo's instructions FIRST" above).
- `readGithubFile`: reads a file from a branch or ref.
- `writeGithubFile`: commits a full file replacement using the Git Data API.
- `patchGithubFile`: reads a file, performs an exact string replacement, and
  commits the result using the Git Data API.
- `createGithubIssue`: creates a GitHub issue.
- `addGithubIssueComment`: adds a comment to an issue or pull request.
- `createGithubPullRequest`: creates a pull request.
- `createGithubRepository`: creates and automatically initializes a new repository (with a default main branch and README.md).
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

Use `createGithubRepository` to create a new repository under the specified owner. This automatically initializes the repository with a default `main` branch and a `README.md` file to prevent subsequent commit errors.

Pass `isPrivate` as `true` (default) to create a private repository, or `false` for a public repository.

**(Note on Personal Accounts)**: GitHub Apps are restricted by platform policy from programmatically creating repositories on personal (non-organization) accounts. If `createGithubRepository` returns a `PERSONAL_ACCOUNT_RESTRICTION` error, you must explain this to the user and instruct them to manually create a private repository named `<repo_name>` at `https://github.com/new` with 'Add a README file' checked. This avoids 403 authorization failures and empty-repository commit errors.

Pass `issueNumber` as a string, for example `"11"`.
