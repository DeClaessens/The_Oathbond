# Dispatch prompt — M2.4 Equip gate & slots

Preconditions: **M2.2 and M2.3 both merged** (attributes to require against;
items to equip). Verify both are on `main`; stop if either is missing.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M2.4 — Equip gate & slots** from the Oathbond development
plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement.
2. `docs/briefs/m2-04-equip-gate-and-slots.md` — the spec. Final; if reality
   contradicts it, stop and report.
3. `docs/adr/0016-derived-stats-one-way-table.md` (you route unequip through
   its dependent-emission helper) and `docs/adr/0015-save-architecture.md`
   (the load order and the two-gates rule).
4. The `oathbond-skill-system` skill, then `components/stats/
   stats_component.gd` (you add `remove_by_source`), `items/core/`
   (M2.3's definitions/instances/catalog), `skills/effects/
   stat_buff_effect.gd` (the modifier-with-source authoring pattern), and
   `components/inventory/inventory_component.gd`.

The task: an `EquipmentComponent` with an 11-slot roster (Ring ×2 over one
item type); one shared `Equipment.validate` legality function (slot match +
attribute requirements) called by the UI *and* by load; equip applies each
affix as a `StatModifier` sourced by the item instance; unequip removes them
via a new `StatsComponent.remove_by_source`; equipment persists and
re-validates at the gate on load; and an equipment panel sharing the
inventory screen.

Three invariants most likely to bite:

- **Unequip = `remove_by_source` once, through the ADR-0016 emission** — a
  plain `_mods.erase` loop that forgets the dependent emission leaves max
  pools/derived stats stale. Prove equip→unequip restores every stat exactly.
- **One legality function** (ADR: the equip gate), and it is *separate* from
  the structural `SaveValidator` — both run on load, different jobs; don't
  fold legality into the save validator (it has no stats to check against).
- **Load order: equipment before health/mana** so pool-boosting gear sets
  max before currents clamp (the ADR-0015 clamp hazard). Amend the load-order
  note.

New `class_name`s ⇒ `--headless --import` once; confirm new tests appear.

Done means: the brief's acceptance criteria hold and are test-backed
(equip/unequip stat symmetry incl derived, validate table, swap, save
round-trip + load-order case + illegal-on-load, `remove_by_source` unit),
the CONTEXT.md entries are written, the suite is green with new tests
verifiably running, committed on `feat/m2-04-equip-gate-and-slots`. The
out-of-scope list (oath/material constraints, crit, tooltips, flasks, sets)
is binding.
