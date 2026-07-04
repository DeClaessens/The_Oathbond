---
name: oathbond-skill-system
description: >-
  Oathbond's composable skill / stat / modifier / damage system. Use when
  adding or changing a Skill, SkillEffect, StatModifier, buff, debuff, damage
  type, projectile, or the StatsComponent / AbilityComponent core — or when
  editing an authored .tres skill asset.
---

# Oathbond skill system

The live `.gd` code is the spec. The authoritative "why" lives in `docs/adr/`;
the vocabulary (Skill vs Effect vs Slot, Buff vs Debuff, Targeting) lives in
`CONTEXT.md`. Don't restate those — link to them.

## Map

The skill-casting machinery is under `res://skills/`. Character-composition
primitives that aren't skill-specific — usable by any character whether or
not it ever casts anything — live in `res://components/` instead (ADR-0007).
GDScript resolves by `class_name`, not path — folders are cosmetic.

- `components/stats/stat_keys.gd` — `StatKeys`: `StringName` stat constants +
  the Inspector-facing `Stat` / `DamageType` enums and their `to_stringname` /
  `damage_type_name` converters.
- `components/stats/stat_modifier.gd` — `StatModifier`: one op (`FLAT` /
  `ADD_PCT` / `MULT_PCT`) on one stat, with duration + stacking policy. Runtime
  state lives here.
- `components/stats/stats_component.gd` — `StatsComponent`: the one authority
  on every number, both directions (`get_stat`, `scale_outgoing`,
  `apply_damage`).
- `components/faction/faction_component.gd` — `FactionComponent`: identity
  only (`Faction.PLAYER` / `ENEMY` / `NEUTRAL`, resolved via
  `FactionComponent.of()`); does not resolve hostility between factions.
- `core/skill.gd` — `Skill` (Resource): pure data, metadata + `effects` array +
  a `Targeting` hint.
- `core/skill_effect.gd` — `SkillEffect` (Resource): base class; override
  `execute(ctx)`.
- `core/skill_context.gd` — `SkillContext`: the carrier passed to every effect.
- `core/ability_slot.gd` — `AbilitySlot`: per-slot cooldown wrapper.
- `core/ability_component.gd` — `AbilityComponent`: 4 slots, ticks cooldowns,
  resolves targeting, fires effects.
- `effects/*.gd` — the concrete effects (`StatBuffEffect`, `DamageEffect`,
  `SpawnProjectileEffect`).
- `projectile/projectile.gd` — `Projectile` (Area2D).
- `library/*.tres` — authored skill assets (`sprint.tres`, `super_jump.tres`).

## The activation flow (current signatures)

`AbilityComponent.activate(index: int, aim_point: Vector2 = Vector2.ZERO)`.
The caller passes only a slot index and an aim *point* (e.g. the mouse
position) — **not a target list**. `activate()` builds the `SkillContext`,
resolves `caster_stats` once via `StatsComponent.of(caster)`, then calls
`_resolve_targeting(skill.targeting, ...)` to fill `ctx.targets` and
`ctx.aim_direction`:

- `SELF` → targets = `[caster]`
- `AREA` → aim_direction = `(aim_point - source_position).normalized()`, no targets
- `NONE` → no targets, no direction
- `ENEMY` / `ALLY` → `push_error` and fail with `&"unresolvable_targeting"` (no
  target-selection system exists yet — fail loudly, never guess)

Effects then run in order over the same `ctx`.

## Adding a new SkillEffect (behavior)

1. Create `skills/effects/<name>_effect.gd`, `class_name <Name>Effect extends
   SkillEffect`.
2. Add `@export` fields for anything a designer tunes. Damage/stat fields use
   the enums: `@export var damage_type: StatKeys.DamageType`, `@export var stat:
   StatKeys.Stat` — never a raw `StringName` in the Inspector (silent-typo
   trap, ADR-0005).
3. Override `execute(ctx: SkillContext)`. Read everything from `ctx`. Resolve a
   target's stats with `StatsComponent.of(target)` and null-check it. Scale
   outgoing damage with `ctx.caster_stats.scale_outgoing(base, damage_type)`.
4. Do **not** touch `Skill`, `AbilityComponent`, or any character script —
   adding behavior is adding a subclass, nothing else.
5. Add a test under `test/` and run the suite (see `godot-gut-tests`).

Done when: the effect compiles, only reaches the scene tree to *write*
(spawning), reads targets solely from `ctx`, and a test exercises it green.

## Authoring / editing a Skill (.tres)

Skills are `Resource` assets in `skills/library/`, normally authored in the
Godot editor: create a `Skill`, set `id` / `display_name` / `cooldown` /
`targeting`, and add `SkillEffect` sub-resources to `effects`. Zero code for a
new buff or damage skill — it's data.

**Editing an existing .tres from code: load, mutate, save — never rebuild**
(ADR-0006). Reconstructing a `Skill.new()` from hardcoded values silently
discards every field a designer tuned.

```gdscript
var s: Skill = load("res://skills/library/sprint.tres")
var eff := s.effects[0] as StatBuffEffect
eff.value = 0.6                       # touch only the field you mean to change
ResourceSaver.save(s, "res://skills/library/sprint.tres")
```

Treat every authored asset as hand-tuned; a full regenerate is never safe.

## Invariants — violating these causes silent, plausible-looking bugs

1. **No runtime state on a Resource.** `Skill` / `SkillEffect` are shared across
   every caster. Cooldown lives on `AbilitySlot`; modifier lifetime on
   `StatModifier` / `StatsComponent`. (ADR-0003)
2. **Effects read only `SkillContext`.** No `get_tree()` / `get_node()` /
   globals to *find* targets. The one allowed scene reach is spawning a
   projectile into `ctx.spawn_parent` — a write, never a read.
3. **The authority on the final number emits the event.**
   `StatsComponent.apply_damage` knows the post-resistance value, so it — and
   only it — emits `Events.damage_dealt`. Effects and `Projectile` never emit
   damage events.
4. **Movement reads `get_stat()` every frame.** Never cache a stat across
   frames; buffs only take effect because `get_stat` recomposes each call.
5. **Signals travel upward.** `AbilityComponent` emits; UI/audio connect to it.
   The component never reaches into UI.
6. **`Events` is cross-cutting only.** A signal exactly one system consumes
   belongs on a node, not on the `Events` autoload.
7. **Neutral comes from the op, base from the source** (ADR-0001). A stat with
   no modifiers equals its base — never reintroduce a per-stat "default 1.0".
   Formula: `(base + Σflat) × (1 + Σadd) × Π(1 + mult)`.
8. **Resolve `StatsComponent` via `StatsComponent.of(node)`.** The child is
   named exactly `StatsComponent`; no raw path strings scattered around.
9. **Author with the enums, run on `StringName`** (ADR-0005). Inspector fields
   are `StatKeys.Stat` / `DamageType`; `execute()` converts once via
   `StatKeys.to_stringname` / `damage_type_name`. Never thread the enum into
   `base_stats` / `get_stat` — `.tres` stores enums as ints, so reordering them
   would silently corrupt saved assets.
