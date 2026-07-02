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

### Cap the Size of Any Always-Loaded Chunk (Token Budget)
*   **Guideline:** No single always-loaded unit may grow without bound. A skill's top-level `SKILL.md` (which is injected into the prompt whenever the skill is active) must stay small — **hard cap ~200 lines / ~1,500 words**; treat anything approaching that as a signal to split. When content exceeds the cap, move it out into **on-demand reference files** under `references/` (loaded only when the relevant task arises) or, if the material is a distinct capability/domain, into a **separate skill** that is learned independently. The top-level `SKILL.md` should contain only the always-relevant core plus a short index pointing to the reference files/skills that hold the detail. Individual reference files should likewise stay focused on one task; split an oversized reference into several rather than letting one balloon.
*   **Rationale:** Every token in an always-loaded chunk is paid on *every* turn for the entire conversation, so bloat in `SKILL.md` (or in an eagerly-read reference) directly and continuously inflates cost and latency and dilutes the model's attention. Distributing detail across lazily-loaded references and separate skills means the agent only pays for the guidance it actually needs, when it needs it — keeping the base prompt lean while still making deep guidance available on demand.

### Every Reference Must Be Reachable (No Orphaned Guidance)
*   **Guideline:** When you split content out of `SKILL.md` or out of an existing reference, you MUST leave a **discovery path** to every new file. Concretely: (1) register each new reference in the `SKILL.md` References index with a one-line description of *when* to read it, phrased so the trigger is obvious to the agent; and (2) whenever a reference points the agent to another topic that now lives in a different file, add an explicit "see `other-file.md`" pointer at that spot. After splitting, verify there is no dangling pointer to a section that was moved, and no new file that nothing links to. A crucial rule the agent can never load is worse than one that is merely long.
*   **Rationale:** References are loaded on demand, so the agent only reads a file if something told it to. Moving content without leaving a link silently drops that guidance from the agent's reachable context — it will confidently act without the rule it never saw (exactly the class of failure where a mandate buried in an unreferenced file gets ignored). Preserving the link graph keeps the token savings of lazy loading without losing coverage.

### Environment Hygiene
*   **Guideline:** Never let skills execute generic commands or download tools (e.g., re-installing runtimes/packages) inside external unconfigured sandboxes. Always leverage built-in, pre-baked persistent VMs where required tools are already cached.

### Describe Intent and Capabilities, Not Specific Tool Invocations
*   **Guideline:** Instructions must state *what needs to happen* (the goal, principle, or capability) and let the agent choose the right tool for the situation. Do NOT pin the runtime plumbing used to invoke a capability. Concretely:
    *   Never hardcode meta-tool call syntax such as `learn_skill("x")`, `unlearn_skill(...)`, `read_skill_reference(...)`, `install_community_skill(...)`, or `run_command({ command: "..." })`. Instead say "learn/activate the `x` skill", "acquire the `x` skill (learn it if available, otherwise install it first)", or "load the `x` reference".
    *   Never assume a single fixed mechanism when several may apply. For example, needing another skill's guidelines is an *intent* ("you must acquire and activate the `p2b-deno-deploy` skill"); whether the agent learns an already-installed skill or first installs it from the registry is a runtime decision the agent should make based on what is currently available to it.
    *   Referring to a skill's own **domain tools by name** (e.g. `list_composio_tools`, or a VM shell command) is fine — that documents a real capability. The anti-pattern is pinning the *platform plumbing* that activates skills or dispatches tool calls, and pinning exact model version numbers (prefer "the latest Gemini/Claude models").
*   **Rationale:** Command interfaces, meta-tool names, and model versions change rapidly. Hardcoding them makes instructions brittle: when the plumbing changes or a dependency isn't installed, the agent follows a dead recipe instead of adapting (a real incident: a skill told the agent to `learn_skill("p2b-deno-deploy")`, which hard-failed because the skill wasn't installed, and the agent then hallucinated instead of installing it). Principle-based instructions let the agent route correctly across contexts and survive platform upgrades.
