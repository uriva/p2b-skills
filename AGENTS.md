# Agent Instructions

- When fixing a bug, add a regression test that fails before the fix and passes
  after it whenever feasible.
- **BUMP TANK VERSION:** Whenever you modify any skill (like editing a `SKILL.md` file), you **MUST** bump the version field in that skill's `tank.json` file. If you do not bump the version, the Tank registry will not publish the new version, and consumer bots (e.g. prompt2bot) will not receive the updated instructions since they lock to the published version.

---

## Skill Writing Principles

### Start from a Failing Production Repro
*   **Guideline:** When fixing any bug, friction point, or validation error, you MUST first reproduce it using the actual production code/test-suite (NOT an isolated mock example or simplified simulation). Run the test locally and confirm that it fails under the original buggy state before applying your changes. Once the fix is applied, run the exact same production test again to confirm it passes. Be extremely sincere and precise.
*   **Rationale:** Simulating mock or isolated examples can mask subtle logic interactions and edge cases, leading to false confidence. Real production test validation ensures correctness and prevents regressions.

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

### Use General Phrasing for Skill Learning & Models
*   **Guideline:** When instructing agents to learn or load other skills, or when referring to AI model capabilities, always use abstract, future-proof phrasing (e.g., "learn the p2b-document-pipeline skill", "use the latest Gemini/Claude models") instead of pinning specific tool/command syntaxes (such as `learn_skill("...")`) or specific model version numbers.
*   **Rationale:** Command interfaces and model versions change rapidly over time. General phrasing prevents instruction guidelines from becoming obsolete or breaking when platform toolsets or models are upgraded.
