# Stat modifiers compose as Flat, then Additive%, then Multiplicative% buckets

Every Stat is produced by `(base + ΣFlat) × (1 + ΣAdd%) × Π(1 + Mult%)`, and a modifier's neutral value comes from its operation (0 for Flat/Add%, 0 → ×1 for Mult%) rather than from the stat itself. We chose three buckets over a single "everything adds" or "everything multiplies" model so gear, buffs, and talents can express both diminishing (additive) and compounding (multiplicative) power sources without any stat needing a per-stat default to remember.

## Consequences

A stat with no modifiers always collapses to its base — there is no "default multiplier of 1.0" to forget and no silent zero-damage trap.
