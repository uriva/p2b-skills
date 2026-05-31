# Agent Instructions

- When fixing a bug, add a regression test that fails before the fix and passes
  after it whenever feasible.
- **BUMP TANK VERSION:** Whenever you modify any skill (like editing a `SKILL.md` file), you **MUST** bump the version field in that skill's `tank.json` file. If you do not bump the version, the Tank registry will not publish the new version, and consumer bots (e.g. prompt2bot) will not receive the updated instructions since they lock to the published version.
