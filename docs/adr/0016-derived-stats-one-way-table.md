# Derived stats: a fixed one-way table, resolved inside get_stat, with dependent emission

Attributes (Might/Grace/Wit) feed a few derived stats — Might → max_health, Wit → max_mana, Grace → crit_multi (the numbers are M2 tuning, decided in the M2.2 brief). ADR-0001's composition is per-stat and independent: `get_stat(X)` reads only `base_stats[X]` and the modifiers whose `.stat == X`, and there is no way for one stat to read another. This ADR adds exactly enough machinery to let a *derived* stat read a *source* stat, and no more.

**The table is one-way and fixed.** A single authored constant on `StatsComponent` maps each derivation:

```gdscript
# source attribute → array of (derived_stat, per_point_factor)
const DERIVATIONS := {
    &"might": [[&"max_health", 2.0]],
    &"wit":   [[&"max_mana", 1.0]],
    &"grace": [[&"crit_multi", 0.005]],
}
```

Sources are always attributes; deriveds are never themselves sources. **Cycles are impossible by construction** — not by a runtime check, but because the table's shape forbids them: a derived stat has no entry, so nothing reads it as a source. This is the "fixed one-way derivation table" the stats-and-gear design doc calls the simple safe shape, chosen over recalculated modifiers or a general dependency graph precisely so no future edit can introduce a cycle without adding a source entry by hand.

**Resolution lives in `get_stat`, at the FLAT tier.** `get_stat(derived)` adds the derived contribution to the composition's base, before the additive- and multiplicative-percent tiers:

```gdscript
func get_stat(stat: StringName) -> float:
    var base: float = base_stats.get(stat, 0.0) + _derived_contribution(stat)
    return _compose(base, _mods_for(stat))

func _derived_contribution(stat: StringName) -> float:
    var total := 0.0
    for source in DERIVATIONS:
        for pair in DERIVATIONS[source]:
            if pair[0] == stat:
                total += get_stat(source) * pair[1]
    return total
```

`get_stat(source)` composes the source attribute's own base + mods (allocation, gear), so the derived value tracks the *total* attribute including gear — requirement-chaining and gear-fed attributes feed derived scaling for free. The single recursion level (derived → source, never further) terminates because sources are never deriveds. Putting the contribution at the FLAT tier means `+% max health` gear amplifies Might-derived health too — a build that stacks Might *and* %-health compounds, which is the intended stat-stacking archetype; a derived value that ignored %-increases would be a surprising exception to how every other stat composes.

**Dependent emission keeps the cached pools correct.** `HealthComponent` and `ManaComponent` cache `_max` and refresh it only on `stat_changed` for their *exact* key (`max_health` / `max_mana`). Independent composition never emits `max_health` when a `might` modifier changes, so without help the pools would go stale. Therefore: **whenever `StatsComponent` emits `stat_changed(X)`, if `X` is a source in the table it also emits `stat_changed(D, get_stat(D))` for each derived `D` that depends on `X`.** This is centralized in one private helper called from every site that currently emits `stat_changed` — `add_modifier`, `remove_modifier`, the remove-by-source path (ADR added in M2.4), and the `_process` expiry sweep — so no emit site can forget it.

## Considered Options

- **Derivation as managed FLAT modifiers, recomputed on `stat_changed`** (the design doc's alternative). Rejected: it duplicates the source-of-truth (the modifier can drift from the attribute that spawned it), needs add/remove bookkeeping on every attribute change, and risks double-counting on load exactly like the M0.4 growth-modifier hazard (ADR-0015). Resolving inside `get_stat` keeps one source of truth — the stat is always recomputed fresh, matching CONTEXT.md's description of a Stat as having "no memory of its own."
- **A general dependency graph with topological sort.** Rejected as speculative generality: three hardcoded one-way pairs do not need a graph engine, and a graph permits cycles that the fixed table forbids by shape.

## Consequences

- `get_stat` is now mildly recursive (one level). The `DERIVATIONS` scan is O(entries) per read; with three entries this is negligible, but a derived stat read in a hot per-frame loop pays it — acceptable at M2's scale, revisit only if profiling says so.
- Adding a new derivation is a one-line table edit plus (if the derived stat is cached by a component) confirming that component refreshes on its key. New attributes or deriveds must never point back into the table as a source of something that feeds them — the reviewer's one check.
- Enemies get derived stats too (ADR-0002 symmetry): an enemy authored with Might gets the health for free. Enemies that should not scale simply carry no attribute base.
- The crit_multi derivation means Grace feeds M2.5's crit pipeline automatically once both merge, in either merge order — Grace with no crit consumer is harmless, crit with no Grace reads the base.
