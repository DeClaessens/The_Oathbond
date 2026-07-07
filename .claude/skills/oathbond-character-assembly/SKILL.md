---
name: oathbond-character-assembly
description: >-
  Assemble or modify an Oathbond character/entity scene (player, enemy, NPC)
  from components. Use when adding a new enemy or entity, attaching or writing
  a component (Health, Mana, Faction, Death responses), editing a .tscn by
  hand, or choosing collision layers/masks.
---

# Character assembly

Characters are composed from sibling component nodes, never subclassed by
type (ADR-0002, ADR-0007): player and enemies use the same components
symmetrically, and no component special-cases "the player". The casting side
(AbilityComponent, Skills, StatsComponent internals) is the
`oathbond-skill-system` skill; this one covers putting a character together.

## The component roster

| Component | Node type | Needs sibling | Provides |
|---|---|---|---|
| `StatsComponent` | Node | — | every number; `base_stats` dict authored in the scene |
| `HealthComponent` | Node2D | StatsComponent (`max_health`) | current-HP pool, `health_changed`/`died` signals, auto-spawns its health bar |
| `ManaComponent` | Node2D | StatsComponent (`max_mana`, `mana_regen`) | current-Mana pool, auto-spawns its mana bar |
| `FactionComponent` | Node | — | identity only (`PLAYER`/`ENEMY`/`NEUTRAL`), never hostility (ADR-0007) |
| `AbilityComponent` | Node | StatsComponent | 4 ability slots (see `oathbond-skill-system`) |
| `DespawnOnDeathComponent` | Node | HealthComponent | `queue_free` on `died` |

Death is latched on `HealthComponent`; *responses* to death are separate
sibling components composed per character (ADR-0012) — a new death behavior
is a new small component connecting to `died`, not an edit to
`HealthComponent`.

## Rules

1. **Exact child names.** Every component is resolved via its static
   `Component.of(node)`, which does `get_node_or_null(^"ComponentName")` —
   the child must be named exactly like the class (`StatsComponent`,
   `HealthComponent`, ...). A renamed child silently resolves to `null`.
2. **New components follow the pattern**: `class_name XComponent`, a static
   `of(node)` resolver, resolve siblings in `_ready()` via their `of()`, and
   `push_error` + degrade gracefully when a required sibling is missing —
   never crash, never silently no-op.
3. **Scene order**: put `StatsComponent` above the components that read it,
   matching the existing scenes (`entities/player/Player.tscn`,
   `entities/enemies/training_dummy/TrainingDummy.tscn`).
4. **Resource pools vs stats** (ADR-0009): `max_health` is a Stat on
   StatsComponent; *current* HP lives on HealthComponent. Never put a
   current-value pool in `base_stats`.

## Collision layers (ADR-0008)

Named in `project.godot`: `World`=1, `Player`=2, `Enemy`=4,
`PlayerProjectile`=8, `EnemyProjectile`=16. A body's `collision_layer` says
what it *is*; its `collision_mask` lists what it may hit. Enemies:
`collision_layer = 4`. A new spawnable side (hazard, pet) gets a **new**
layer — never reuse one, and never gate hits through `FactionComponent`.

## Hand-editing .tscn files

Prefer copying the structure of an existing entity scene. When editing text
directly:

- Reference scripts with a path-only `[ext_resource type="Script"
  path="res://..." id="N_name"]` — omit `uid=`; the editor fills uids on its
  next save. **Never invent or copy a uid** — a duplicated uid silently
  misresolves resources project-wide.
- Same for node `unique_id=` attributes: existing ones keep, new nodes get
  none (editor-assigned).
- `base_stats` keys are raw `StringName` strings in the scene file and must
  match `components/stats/stat_keys.gd` constants exactly — a typo is a
  silent zero, there is no enum protection at this layer.
- Companion `.uid` files next to scripts are part of the project — commit
  them, never regenerate by hand.
- After adding a new scene or `class_name` script, refresh the cache
  (`godot-headless` skill) or headless runs — including tests — won't see it.

Done when: the scene boots in a headless smoke-run with no new
`SCRIPT ERROR`/`push_error` output, and a GUT test exercises the new
component (see `godot-gut-tests`).
