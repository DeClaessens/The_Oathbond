# M2-02 — Attributes (Might / Grace / Wit)

*Depends on M2.1 (ADR-0016). First consumer of the derived-stats machinery.*

## Goal

The three attributes become live stats a player grows and spends. Each level
grants points; points allocate freely into Might, Grace, or Wit; allocation
moves derived stats (max health, max mana, crit multiplier) you can watch
change; a respec returns the points. This is the level-up *decision* that
pairs with M0.4's automatic growth — the first build lever the player pulls.
Design source: `docs/design/stats-and-gear.md` (Attributes section);
mechanism contract: ADR-0016.

## Design decisions (made — do not reopen)

1. **Attribute names are final: `&"might"`, `&"grace"`, `&"wit"`** (locked
   2026-07-08). They are ordinary stats — modifiable like any other, gear
   can add them later (M2.4) — with no `StatKeys.enum Stat` entry (they are
   string-keyed like `dmg_<type>`, not enum stats; ADR-0005's enum is for
   the fixed authored set, and attributes are append-only-safe as bare
   StringNames). Add them as `StatKeys` string constants
   (`MIGHT`/`GRACE`/`WIT`) so no code stringly-types them.
2. **Implement the ADR-0016 derived-stats machinery in `StatsComponent`**
   as specified there: the `DERIVATIONS` table (`might`→`max_health` ×2.0,
   `wit`→`max_mana` ×1.0, `grace`→`crit_multi` ×0.005), `_derived_contribution`
   folded into `get_stat` at the FLAT tier, and the dependent-emission
   helper called from every `stat_changed` emit site. This is the
   foundational half of the story; do it first and test it in isolation
   before the allocation UI.
3. **`AttributesComponent`** (`components/attributes/attributes_component.gd`,
   `class_name AttributesComponent extends Node`), sibling of
   `StatsComponent`, found by the `of()` convention. It owns the allocation
   as its source of truth:
   - `var _allocated := {&"might": 0, &"grace": 0, &"wit": 0}` and
     `var _unspent := 0`.
   - It applies each attribute's allocated count as a single **FLAT
     `StatModifier`** on that attribute stat, `source = self`,
     `duration = 0.0` (permanent), `key` per-attribute so re-allocation
     REFRESHes rather than stacks. On any allocation change it updates the
     three modifiers and lets `StatsComponent`'s dependent-emission move the
     derived stats.
   - `func allocate(attr: StringName) -> bool` — spends one unspent point
     into `attr` if `_unspent > 0`; returns success.
   - `func respec() -> void` — returns all allocated points to `_unspent`,
     zeroes `_allocated`, resyncs modifiers. **Free and unlimited at M2**
     (no currency system exists yet); the cost hook is a one-line TODO
     citing the design doc's "cheap early, real later" — do not invent a
     currency.
   - Signals `attributes_changed()` and `points_changed(unspent: int)`
     (local, not `Events` — UI is the only consumer, per the M0.4 pattern).
4. **Points come from leveling.** `AttributesComponent` connects to the
   sibling `ExperienceComponent`'s `leveled_up` signal and adds
   `POINTS_PER_LEVEL := 3` unspent points per level (tunable constant).
   Level 1 starts with `STARTING_POINTS := 3` to spend so a fresh character
   has an immediate decision. Base attribute values start at 0 — there is
   **no class starting spread yet** (classes are M5/M6); leave a documented
   hook (a settable base, or a comment) but do not build a class system.
5. **Allocation persists through the M1 save system.** Add
   `save_state()`/`load_state()` to `AttributesComponent` returning/consuming
   `{"allocated": {...}, "unspent": int}`. On load it sets the counts and
   reapplies the modifiers (never double-applies — same replay discipline as
   ADR-0015's growth). Add an `"attributes"` section to the character
   document schema (version stays 1 — additive optional section; a v1
   document lacking it validates to the zero allocation). Extend
   `SaveValidator.validate_character` with attribute rules (see decision 6)
   and place the attributes step in the load order **after experience,
   before health/mana** so derived max pools are correct before the pools
   clamp their persisted currents.
6. **Validator rules (the ADR-0015 gate):** `allocated` must be a dict of
   the three known attrs → non-negative ints (unknown keys dropped with a
   warning, missing keys default 0, negatives clamped to 0 with a warning);
   `unspent` a non-negative int (mistyped → 0 with a warning). No
   cross-check against level total at M2 (a tampered save that over-allocated
   is a cosmetic exploit, not a crash — a `total ≤ earned` check is a noted
   future tightening, not M2 scope).
7. **Minimal attributes panel** (`ui/attributes/attributes_panel.gd` +
   `.tscn`): shows the three attribute totals (`get_stat` values), unspent
   points, a `+` button per attribute (disabled when `_unspent == 0`), and a
   Respec button. It binds to `AttributesComponent` signals and reflects the
   derived stats live (read `get_stat(max_health)` etc. and update on
   `attributes_changed`). Toggle visibility with a new input action
   `toggle_attributes` (bind to `C`). Functional, not styled — mirror the
   existing HUD wiring idiom (`ui/skill_bar/`), read-then-command like the
   skill bar mirrors `AbilityComponent`.

## Invariants to respect

- ADR-0016 is the contract for derivation — implement it exactly, especially
  the dependent-emission from *every* emit site, or the pools go stale when
  attributes change (the trap the ADR exists to prevent).
- ADR-0001: allocation is a FLAT modifier, never a mutation of `base_stats`;
  gear will add its own Might modifiers later and both must compose.
- ADR-0015 replay discipline: persist the allocation *counts* and reapply
  modifiers on load; never serialize the `StatModifier`s (double-apply trap).
- ADR-0002 symmetry: `AttributesComponent` assumes nothing player-specific;
  it is a component any character could carry.
- Load order (decision 5) is load-bearing: attributes before pools.

## Documentation this brief owes

- **CONTEXT.md**: entries for **Attribute** (Might/Grace/Wit — player-grown
  stats that gate gear (later) and feed derived stats; _avoid_: ability
  score as a synonym in code), **Derived Stat** (a stat computed partly from
  another via the one-way table — max_health from Might, max_mana from Wit,
  crit_multi from Grace; cite ADR-0016), and **Attribute Point** (the
  per-level allocation currency; unspent until spent, respec returns them).
- ADR-0016 already exists — cite it; do not write a new ADR.

## Acceptance criteria

- Leveling grants `POINTS_PER_LEVEL` unspent points; a fresh character has
  `STARTING_POINTS` to spend at level 1.
- Allocating a point into Might raises `get_stat(&"might")` by 1 and
  `get_stat(max_health)` by 2.0, and the cached `HealthComponent` max
  reflects it (the pool's max actually moves, proving dependent emission).
  Wit → max_mana ×1.0 and Grace → crit_multi ×0.005 likewise.
- `+%` max-health gear/modifier stacked with Might-derived health multiplies
  the derived contribution too (FLAT-tier placement, ADR-0016).
- Respec returns every allocated point to unspent and drops the derived
  bonuses back to base.
- Save with points allocated, rebuild the scene, load: allocation, unspent
  count, and every derived max match exactly, with no double-application
  (a save→load→save round-trip produces an identical document).
- A tampered `attributes` section (unknown attr key, negative count,
  mistyped `unspent`) loads sanitized with one warning per repair.
- The panel shows the three attributes and unspent points, `+` allocates and
  disables at zero unspent, Respec resets, and the derived numbers update
  live.
- Full GUT suite green (new `class_name` ⇒ `--headless --import` first;
  confirm new test files appear in the run).

## Test ideas

- Derived machinery in isolation: a bare `StatsComponent` with
  `base_stats = {might: 10}` → `get_stat(max_health)` includes +20; add a
  might FLAT modifier → `stat_changed(max_health)` fires (watch_signals) and
  the value tracks; remove it → tracks back.
- Pool refresh: entity with Stats+Health, raise might → `HealthComponent`
  max rises (proves dependent emission reaches the cached pool).
- Allocation: `allocate` with/without unspent points; `respec` restores.
- Save round-trip and replay equivalence, mirroring the M1.2 tests.
- Validator table: each malformed attribute input → sanitized output +
  warning count.

## Out of scope

- Class starting spreads (no class system until M5/M6 — hook only).
- Respec *cost* / any currency or economy (M4).
- Gear granting `+attribute` (that is M2.4 — this story only makes the
  attribute stats exist and be allocatable).
- Attribute *requirements* on gear (M2.4's equip gate).
- Heirloom stat-stacking hooks ("+Ember per 10 Wit") — M2.5/later.
- Panel styling, tooltips, animations — functional only.
- New derivations beyond the three in ADR-0016.
