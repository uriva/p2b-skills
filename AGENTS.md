# Agent Instructions

- **BUMP TANK VERSION:** Whenever you modify a skill (`SKILL.md`, `references/`,
  etc.), you **MUST** bump the `version` in that skill's `tank.json`. Without a
  version bump, Tank will not publish the update and consumers stay locked to
  the old version.
- **Start from a Failing Production Repro:** Reproduce bugs against the real
  production code/test suite (never an isolated mock simulation), confirm the
  test fails before your change, and confirm it passes after.

## Skill Writing Principles

- **Cap Always-Loaded Context (`SKILL.md` ≤ ~400 lines):** Every token in
  `SKILL.md` is paid on every turn. Keep `SKILL.md` focused on core principles
  and move detailed task guidance into on-demand files under `references/` (or a
  separate skill).
- **Every Reference Must Be Reachable:** Whenever you move content into
  `references/`, register the file in `SKILL.md`'s References index with a clear
  one-line trigger description, and update any cross-file pointers so no
  reference is orphaned.
- **Principle-Based over Recipe-Based:** State core behavioral principles and
  constraints rather than brittle step-by-step recipes, unless a strict sequence
  is technically required.
- **Describe Intent, Not Platform Plumbing:** Never hardcode meta-tool syntax
  (`learn_skill("x")`, `read_skill_reference(...)`, `install_community_skill`,
  exact model version strings). State the required capability (e.g. "acquire and
  activate the `p2b-whatsapp` skill") so the agent can either learn or install
  it as needed. Referring to a skill's own domain tools by name is fine.
- **Prevent Active Context Bloat:** Use paginated searches or two-step
  search-then-inspect patterns instead of dumping large schemas on Turn 1.
- **Avoid Tool Duplication & Re-Installations:** Do not duplicate tool schemas
  across skills, and rely on pre-baked persistent VM tooling rather than
  re-installing runtimes in ephemeral sandboxes.
