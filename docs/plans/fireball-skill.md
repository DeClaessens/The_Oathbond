# Fireball — implementation handoff

The first damage-dealing Skill: an aim-and-fire projectile that deals 50 Fire
damage on contact. No special effects — just exercising the existing
`SpawnProjectileEffect` → `Projectile` → `StatsComponent.apply_damage` pipeline
for the first time (both effects exist today but no authored Skill uses either
yet).

This document is the complete spec. It is self-contained: an implementer should
not need to re-derive any decision. All decisions below were settled in a design
grill; the "Why" notes exist so you don't reopen them.

See ADR-0008 for why a `PlayerProjectile` hitting `Enemy` needs no new collision
wiring — it already works today.

---

## 1. Scope

**In:** one new Skill (`fireball.tres`) using the existing `SpawnProjectileEffect`
and the existing generic `Projectile` scene, equipped to slot 2, plus a bare
placeholder visual on `Projectile` (it currently renders nothing) and a GUT test
covering the hit → damage path end to end.

**Out (do not build):** a dedicated `FireballProjectile` scene/script, particle
or trail VFX, an explosion/AoE radius, piercing, a resource cost, death/kill
handling on the target (Training Dummy has 999,999 HP specifically so this
doesn't come up yet), any new InputMap action (aiming already works via
`get_global_mouse_position()` → `AbilityComponent.activate`).

---

## 2. `skills/library/fireball.tres` (new)

Mirrors `skills/library/sprint.tres`'s structure, but with `targeting = AREA`
(`3`) and a `SpawnProjectileEffect` sub-resource instead of a `StatBuffEffect`.

```
[gd_resource type="Resource" script_class="Skill" format=3]

[ext_resource type="Script" path="res://skills/core/skill_effect.gd" id="1_effect"]
[ext_resource type="Script" path="res://skills/effects/spawn_projectile_effect.gd" id="2_spawn"]
[ext_resource type="Script" path="res://skills/core/skill.gd" id="3_skill"]
[ext_resource type="PackedScene" path="res://skills/projectile/projectile.tscn" id="4_proj"]

[sub_resource type="Resource" id="Resource_fireball_spawn"]
script = ExtResource("2_spawn")
projectile_scene = ExtResource("4_proj")
speed = 600.0
base_damage = 50
damage_type = 1

[resource]
script = ExtResource("3_skill")
id = &"fireball"
display_name = "Fireball"
description = "Launches a bolt of fire that deals damage on impact."
cooldown = 0.5
targeting = 3
effects = Array[ExtResource("1_effect")]([SubResource("Resource_fireball_spawn")])
```

Notes:
- `speed = 600.0`, `base_damage = 50`, `damage_type = 1` (Fire) are
  `SpawnProjectileEffect`'s own script defaults — written explicitly here so
  the values are visible in the inspector/asset, not because they differ from
  the default. **Why:** confirmed in the grill — no reason to invent new
  numbers, and the travel distance from Player to Training Dummy (~660px) is
  well inside 600px/s × 3s lifetime either way.
- No `icon` is set. **Why:** no icon art exists yet; the skill bar slot will
  show the existing letter-fallback (`F`), same as any other icon-less skill.
- Omit any `uid=` attribute — Godot assigns one the first time the file is
  opened/saved in the editor. Don't hand-invent a hex value.
- No `resource_cost` line — leave the `Skill` script default (`0`). **Why:**
  no resource system is wired up anywhere in the project yet; this isn't a
  Fireball-specific decision.

---

## 3. `entities/player/player.gd` — equip into slot 2

```gdscript
func _ready() -> void:
	abilities.caster = self

	var sprint: Skill = load("res://skills/library/sprint.tres")
	var super_jump: Skill = load("res://skills/library/super_jump.tres")
	var fireball: Skill = load("res://skills/library/fireball.tres")   # NEW
	learn_skill(sprint)
	learn_skill(super_jump)
	learn_skill(fireball)                                              # NEW
	abilities.equip(sprint, 0)
	abilities.equip(super_jump, 1)
	abilities.equip(fireball, 2)                                       # NEW
```

Key `3` (→ `AbilityComponent.activate(2, ...)`) already routes here via
`Player._unhandled_input` — no InputMap change needed.

---

## 4. `skills/projectile/projectile.gd` — bare placeholder visual

`Projectile` (an `Area2D`) currently draws nothing — nothing has spawned one
before now. Add a `_draw()` override rather than a `Sprite2D` child + a new
texture asset file, since there's no art to load and the shape only needs to
be a static circle that travels with the node's own transform:

```gdscript
func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	draw_circle(Vector2.ZERO, 8.0, Color.ORANGE_RED)
```

(`8.0` matches the existing `CircleShape2D` radius in `projectile.tscn` — keep
them in sync if either changes.) **Why this over a Sprite2D:** "bare minimum"
was the explicit brief — this needs zero new scene nodes and zero new asset
files, and is trivial to replace with a real sprite later without touching any
other file. No animation, no particles, no trail.

---

## 5. Collision — no changes needed

`Projectile` is `collision_layer = 8` (PlayerProjectile), `collision_mask = 5`
(World | Enemy). Training Dummy is `collision_layer = 4` (Enemy). The hit
already resolves through the existing 5-layer scheme — see ADR-0008. Nothing
in this section needs editing; this is here so the implementer doesn't go
looking for a collision change that isn't required.

---

## 6. Testing (GUT)

New file: `test/library/test_fireball.gd`, mirroring `test/library/test_sprint.gd`
(load the real `.tres`, exercise the real effect — not a mock).

Expected math (confirmed in the grill): the caster has no `dmg_fire` modifiers
and the target has no `resist_fire` stat, and both default to `0` in
`StatsComponent._mods_for` / `get_stat`. So `scale_outgoing(50, FIRE)` returns
exactly `50.0`, and `apply_damage` should remove exactly `50.0` HP — assert the
exact number, not an approximation.

```gdscript
extends GutTest

func test_fireball_projectile_deals_fire_damage_on_hit():
	var skill: Skill = load("res://skills/library/fireball.tres")
	var effect: SpawnProjectileEffect = skill.effects[0]

	var caster := Node2D.new()
	var caster_stats := StatsComponent.new()
	caster_stats.name = "StatsComponent"
	caster.add_child(caster_stats)
	add_child_autofree(caster)

	var target := Node2D.new()
	var target_stats := StatsComponent.new()
	target_stats.name = "StatsComponent"
	target_stats.base_stats = {StatKeys.HEALTH: 100.0}
	target.add_child(target_stats)
	add_child_autofree(target)

	var spawn_parent := Node.new()
	add_child_autofree(spawn_parent)

	var ctx := SkillContext.new()
	ctx.caster = caster
	ctx.caster_stats = caster_stats
	ctx.source_position = Vector2.ZERO
	ctx.aim_direction = Vector2.RIGHT
	ctx.spawn_parent = spawn_parent

	effect.execute(ctx)

	var projectile: Projectile = spawn_parent.get_child(0)
	assert_eq(projectile.damage, 50.0)
	assert_eq(projectile.damage_type, StatKeys.DamageType.FIRE)

	projectile._on_body_entered(target)

	assert_eq(target_stats.get_stat(StatKeys.HEALTH), 50.0)
```

Optional second case, if time allows: assert `_on_body_entered(caster)` is a
no-op (the projectile ignores its own caster) — `damage_effect`/`sprint` tests
don't currently cover a "does nothing" branch like this, so it's not required
to match precedent, just worth considering.

---

## 7. Wiring checklist

1. `skills/library/fireball.tres` — new (§2).
2. `entities/player/player.gd` — load/learn/equip Fireball into slot 2 (§3).
3. `skills/projectile/projectile.gd` — add `_draw()` placeholder visual (§4).
4. `test/library/test_fireball.gd` — new (§6). Run headless via the
   `godot-gut-tests` skill; must be green.
5. `docs/adr/0008-five-layer-collision-scheme.md` — already written; no further
   action.
6. Manual verify: run `main.tscn`, press `3`, aim at the Training Dummy, confirm
   an orange-red circle travels from the player toward the cursor and the
   dummy visibly registers a hit (watch `Events.damage_dealt` in the debugger
   or add a temporary print, since the dummy's HP bar won't visibly move at
   999,999 HP). Press `3` again inside 0.5s and confirm `skill_failed` fires
   (`on_cooldown`).

---

## 8. Assumed defaults (flag if you disagree, don't silently change)

- Circle color `Color.ORANGE_RED` — arbitrary placeholder, restyle freely later.
- No sound effect — out of scope, not mentioned in the grill.
- Skill slot 2 / key `3` — settled, not a placeholder; see §1.
