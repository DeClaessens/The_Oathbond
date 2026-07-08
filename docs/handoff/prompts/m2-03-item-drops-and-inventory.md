# Dispatch prompt — M2.3 Item drops & inventory

Preconditions: M2.1 done and Epic M1 merged. Independent of M2.2 (parallel
OK). Verify the brief and ADR-0015 exist; stop if not.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M2.3 — Item drops & inventory** from the Oathbond
development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement.
2. `docs/briefs/m2-03-item-drops-and-inventory.md` — the spec. Final; if
   reality contradicts it, stop and report.
3. `docs/adr/0003-no-runtime-state-on-resources.md` and
   `docs/adr/0015-save-architecture.md` — the definition/instance split and
   the save gate you extend.
4. The `oathbond-character-assembly` skill (you add components, a pickup
   scene, and collision layers), then `skills/core/skill_catalog.gd` +
   `skills/skill_catalog.tres` (the catalog pattern to mirror exactly),
   `components/experience/xp_reward_component.gd` (the victim-component
   pattern `LootComponent` copies), and `save/save_validator.gd`.

The task: authored `ItemDefinition` Resources + rolled `ItemInstance` save
data (never a Resource); an `ItemRoller` that rolls rarity + affixes from a
per-slot-family `AffixPool`; an `ItemCatalog` twin of `SkillCatalog`; a
`LootComponent` on the Slime that spawns a world `DroppedItem` on death; an
`InventoryComponent` that persists through the save system; and a minimal
inventory panel that shows each item's *rolled* values.

Three invariants most likely to bite:

- **Instances are `RefCounted` save data, never Resources** (ADR-0003) —
  rolling never writes to a definition or the catalog; persisted as plain
  dicts through the single `SaveValidator` gate (ADR-0015).
- **`ItemCatalog` mirrors `SkillCatalog` exactly** — lazy static lookup,
  `push_error` on duplicate/empty ids, completeness test against `items/`.
- Pickup `Area2D` uses the five-layer collision scheme (ADR-0008), detecting
  the player only.

New `class_name`s ⇒ run `--headless --import` once and confirm new test
files appear in GUT's output.

Done means: the brief's acceptance criteria hold and are test-backed (roller
invariants, loot-on-death, pickup, inventory save round-trip + validator
table, catalog completeness), the CONTEXT.md entries the brief owes are
written, the suite is green with new tests verifiably running, committed on
`feat/m2-03-item-drops-and-inventory`. The out-of-scope list (equipping,
requirements enforcement, Heirlooms, tier scaling, currency, UI styling) is
binding — items only *exist* and are *held* here, they do not yet change
stats.
