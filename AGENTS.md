# Agent Instructions

- When fixing a bug, add a regression test that fails before the fix and passes
  after it whenever feasible.
- **BUMP TANK VERSION:** Whenever you modify any skill (like editing a `SKILL.md` file), you **MUST** bump the version field in that skill's `tank.json` file. If you do not bump the version, the Tank registry will not publish the new version, and consumer bots (e.g. prompt2bot) will not receive the updated instructions since they lock to the published version.

---

## Skill Writing Principles

### Avoid Tool Duplication
*   **Guideline:** Do not duplicate existing tool names, schemas, or functionality across skills unless absolutely necessary.
*   **Rationale:** Duplication creates maintenance overhead and confuses LLMs with overlapping choices, leading to non-deterministic routing. Rely on cross-skill composition instead.

### Principle-Based over Recipe-Based
*   **Guideline:** Focus instructions on core behavioral principles, constraints, and standard patterns rather than strict step-by-step recipes (unless a strict sequence is technically required).
*   **Rationale:** LLMs excel at adapting principles to dynamic contexts, whereas hardcoded recipes break easily under real-world deviations and lead to retraction loops.

### Prevent Active Context Bloat
*   **Guideline:** Design tool-listing and discovery patterns to be lightweight. Use paginated searches, app-specific filters, or a two-step "Search-and-Inspect" model (list tool slugs first -> inspect full schema on demand).
*   **Rationale:** Massive tool lists and schema dumps loaded on Turn 1 persist in active history, bloating prompt token consumption and inflating costs across all subsequent turns.

### Short, Linkable Sections
*   **Guideline:** Keep each guideline and principle short, atomic, and scoped under a clean Markdown header anchor.
*   **Rationale:** Clear, short sections can be easily referenced, cited, or linked to in PR descriptions, other skill references, and prompt configurations.

### Environment Hygiene
*   **Guideline:** Never let skills execute generic commands or download tools (e.g., re-installing runtimes/packages) inside external unconfigured sandboxes. Always leverage built-in, pre-baked persistent VMs where required tools are already cached.
