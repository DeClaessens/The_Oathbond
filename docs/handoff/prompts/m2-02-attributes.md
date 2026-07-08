# Dispatch prompt — M2.2 Attributes

Preconditions: M2.1 done (ADR-0016 + this brief exist) and Epic M1 merged.
No sibling story must merge first, but M2.4 depends on this — verify ADR-0016
exists; stop if not.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M2.2 — Attributes (Might / Grace / Wit)** from the Oathbond
development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement (definition of
   done, test workflow).
2. `docs/adr/0016-derived-stats-one-way-table.md` — the mechanism you
   implement; it is the contract.
3. `docs/briefs/m2-02-attributes.md` — the spec. Every decision is final; if
   reality contradicts it, stop and report instead of improvising.
4. The `oathbond-skill-system` skill, then `components/stats/`
   (`stats_component.gd`, `stat_keys.gd`, `stat_modifier.gd`),
   `components/experience/experience_component.gd`, and `save/` +
   `components/*/` `save_state`/`load_state` as the persistence pattern to
   copy.

The task, in two halves. First, the ADR-0016 machinery in `StatsComponent`:
the one-way `DERIVATIONS` table, `_derived_contribution` folded into
`get_stat` at the FLAT tier, and the dependent-emission helper called from
*every* site that emits `stat_changed`. Build and test this in isolation
first. Second, `AttributesComponent`: it owns the allocation (points from
leveling, `allocate`/`respec`), applies it as FLAT modifiers to
`might`/`grace`/`wit`, persists through the M1 save system, and drives a
minimal allocation panel.

Three invariants most likely to bite:

- **Dependent emission from every emit site** — if changing `might` doesn't
  emit `stat_changed(max_health)`, the cached `HealthComponent` max goes
  stale. This is the whole point of ADR-0016.
- **Persist allocation counts, replay modifiers** (ADR-0015) — never
  serialize the `StatModifier`s; the load-order slot is after experience,
  before health/mana.
- Allocation is FLAT modifiers, never `base_stats` mutation (ADR-0001).

New `class_name AttributesComponent` ⇒ run `--headless --import` once and
confirm your new test files appear in GUT's output.

Done means: the brief's acceptance criteria hold and are test-backed
(derived machinery in isolation, pool-refresh, allocation, save round-trip +
replay equivalence, validator table), the CONTEXT.md entries the brief owes
are written, the full suite is green with new tests verifiably running, and
the work is committed on `feat/m2-02-attributes`. The out-of-scope list
(class spreads, respec cost/currency, gear +attributes, requirements, panel
styling) is binding.
