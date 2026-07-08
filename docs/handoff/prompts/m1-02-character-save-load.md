# Dispatch prompt — M1.2 Character save/load

Preconditions: Epic M0 merged to main (it is, as of 2026-07-07) and
ADR-0015 + the m1-02 brief exist. Verify before dispatching; the agent
stops if unmet.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M1.2 — Character save/load** from the Oathbond
development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement. Mandatory;
   it defines the definition of done and the test workflow.
2. `docs/adr/0015-save-architecture.md` — the architecture this story
   realizes.
3. `docs/briefs/m1-02-character-save-load.md` — the spec. Every design
   decision in it is final; if reality contradicts it, stop and report
   instead of improvising.
4. The `oathbond-skill-system` skill, then `components/experience/`,
   `components/health/`, `components/mana/`, `skills/core/`
   (`skill.gd`, `ability_component.gd`), and `entities/player/player.gd`.

The task: a `SaveManager` autoload that persists one character to
`user://saves/characters/default.json` (plus `user://saves/account.json`)
on quit and restores it at startup. Components own their own
`save_state()`/`load_state()`; a new authored `SkillCatalog` resource
resolves persisted skill ids; every loaded document passes through
`SaveValidator.validate_character` — the single gate — before any state
applies.

Three invariants most likely to bite, worth restating:

- **Never serialize `StatModifier`s.** Level-up growth is replayed from
  the persisted `level` via the split-out `_apply_growth_modifiers()`;
  saving the modifiers double-applies growth on load.
- **Load order is fixed** — experience, then health, then mana, then
  skills — so growth raises max pools before currents are clamped, and
  the level-up full-restore never clobbers persisted pools.
- Skills persist as `Skill.id` through the catalog, never as resource
  paths; character state never lands on a Resource (ADR-0003).

New `class_name`s (`SkillCatalog`, `SaveValidator`) mean you must run
`--headless --import` once and confirm your new test files actually appear
in GUT's output before trusting a green run.

Done means: the brief's acceptance criteria each hold and are covered by
GUT tests (the brief's "Test ideas" sketches them — round-trip, replay
equivalence, validator table, disk layer, catalog completeness), the
CONTEXT.md entries the brief owes are written, the full suite is green
with new test files verifiably running, and the work is committed on
`feat/m1-02-character-save-load`. The brief's out-of-scope list (no UI,
no multi-character, no autosave, no position/buff/cooldown persistence)
is binding.
