# Inspector-facing Stat/DamageType enums convert to StringName; the runtime stays StringName-keyed

`StatModifier.stat`, `StatsComponent.base_stats`, and related runtime code remain `StringName`-keyed. Only the Inspector-editable effect fields (`StatBuffEffect.stat`, `DamageEffect.damage_type`, `SpawnProjectileEffect.damage_type`) became enums, converted back to the existing `StringName` constants via `StatKeys.to_stringname`/`damage_type_name`. This closes off free-typed Inspector fields (a mistyped `"move_speeed"` was previously a silent no-op) without touching the runtime representation.

## Considered Options

Threading the enum into the runtime directly was rejected for two reasons: `.tres` files serialize enums as raw ints, so inserting a new enum entry later would silently repoint every existing asset at the wrong stat; and compound keys like `dmg_fire`/`resist_fire` aren't enumerable without a combinatorial enum that would need to be kept in lockstep by hand.
