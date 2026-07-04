# Health Bar — implementation handoff

A visible health bar for Player and Training Dummy: full green at max, red
revealed from the right as Health drops. This is also where current HP moves
out of `StatsComponent` into a new `HealthComponent` — see ADR-0009 for why.

This document is the complete spec. It is self-contained: an implementer
should not need to re-derive any decision. All decisions below were settled
in a design grill; the "Why" notes exist so you don't reopen them.

Read ADR-0009 first — it explains *why* HP is moving, this doc only covers
*how*.

---

## 1. Scope

**In:** a new `components/health/` pair (`HealthComponent` owns the pool +
`apply_damage`, `HealthBar` is the pure view it spawns as a child), added to
both `Player.tscn` and `TrainingDummy.tscn`; the `StatsComponent` changes
ADR-0009 requires (`mitigate_incoming`, deleting `apply_damage`, removing
`HEALTH` from `StatKeys`); the `Projectile` call-site change; test coverage
for `HealthComponent`; updates to the two existing test files this touches.

**Out (do not build):** a `died`/`depleted` signal (nothing consumes it yet —
add it when a real death-handling feature needs it), healing/regen, an
upper-clamp-to-new-max-on-buff behavior (if `Max Health` ever rises via a
future modifier, current HP is left untouched — the bar's ceiling moves, HP
doesn't auto-heal to fill it; revisit if a real Vitality-style skill ever
needs otherwise), damage-type color coding on the bar itself, a player-only
screen-space HUD bar (this is a world-space bar above the entity, for both
Player and enemies alike).

---

## 2. Architecture

```
components/health/
├── health_component.gd     # class_name HealthComponent, extends Node
└── health_bar.gd            # class_name HealthBar, extends Node2D
```

No `.tscn` wrapper for `HealthComponent` — like `StatsComponent`/
`FactionComponent`, it's a bare script attached directly to a plain `Node` in
each entity's own scene file. `HealthBar` **does** get its own `.tscn`
(`components/health/health_bar.tscn`, a bare `Node2D` root with
`health_bar.gd` attached — no children needed, it draws itself), because
`HealthComponent` instances one as its child in code:

```
Player.tscn / TrainingDummy.tscn
├── ...
├── StatsComponent
└── HealthComponent          # NEW — Node2D, health_component.gd
     └── HealthBar           # spawned in HealthComponent._ready(), not authored in the .tscn
```

**Why `HealthComponent` is a `Node2D`, unlike `StatsComponent`/
`FactionComponent`:** it hosts a `Node2D` child (`HealthBar`) that needs to
render at the entity's position. Godot's 2D transform inheritance only
composes through a chain of `CanvasItem` ancestors (`Node2D`/`Control`) — a
plain `Node` in that chain does **not** get skipped, it makes everything
below it a top-level canvas item detached from the actual parent's
transform. (This was tried as a plain `Node` first and the bar rendered in
the wrong place — corrected here so the mistake doesn't get repeated.)
`StatsComponent`/`FactionComponent` stay plain `Node`s because neither owns
a 2D visual, so the distinction doesn't apply to them.

---

## 3. `components/stats/stats_component.gd` — changes

Remove `apply_damage` entirely. Add `mitigate_incoming`, the incoming-damage
counterpart to the existing `scale_outgoing`:

```gdscript
func mitigate_incoming(raw: float, type: StatKeys.DamageType) -> float:
	var resist := clampf(get_stat(StatKeys.resist(StatKeys.damage_type_name(type))), 0.0, 0.9)
	return raw * (1.0 - resist)
```

Update the class doc-comment — the `apply_damage` exception it calls out no
longer exists once `apply_damage` moves out:

```gdscript
## Read get_stat() every frame -- do not cache.
```

(Drop the `apply_damage excepted` clause from the first line; the modifier
pipeline now has no exceptions.)

Also remove the stray `print(source, owner, type)` debug line that was
sitting in the old `apply_damage` — it isn't debugging anything relevant to
this change, but it's on the exact line being deleted, so clean it up while
you're there rather than carrying it into `HealthComponent`.

---

## 4. `components/stats/stat_keys.gd` — changes

Remove `HEALTH` and `Stat.HEALTH`. `MAX_HEALTH`/`Stat.MAX_HEALTH` are
untouched — `Max Health` is still a genuine Stat.

```gdscript
const MOVE_SPEED    := &"move_speed"
const JUMP_VELOCITY := &"jump_velocity"
const MAX_HEALTH    := &"max_health"
# HEALTH removed -- Health is a Resource Pool now, not a Stat. See ADR-0009.
```

```gdscript
enum Stat {
	MOVE_SPEED,
	JUMP_VELOCITY,
	MAX_HEALTH,
	OUTGOING_DAMAGE,
	RESISTANCE,
}
```

Remove the corresponding `Stat.HEALTH: return HEALTH` line from
`to_stringname`'s `match`.

---

## 5. `components/health/health_component.gd` (new)

```gdscript
class_name HealthComponent
extends Node

## Owns the current-HP Resource Pool. Max Health is still a Stat on the
## sibling StatsComponent -- resolved once at _ready() and re-read from
## stat_changed if it ever moves (e.g. a future Max Health buff).

signal health_changed(current: float, max: float)

var _current: float
var _max: float
var _stats: StatsComponent

static func of(node: Node) -> HealthComponent:
	if node == null:
		return null
	return node.get_node_or_null(^"HealthComponent") as HealthComponent

func _ready() -> void:
	_stats = StatsComponent.of(get_parent())
	_max = _stats.get_stat(StatKeys.MAX_HEALTH)
	_current = _max
	_stats.stat_changed.connect(_on_stat_changed)

	var bar: HealthBar = preload("res://components/health/health_bar.tscn").instantiate()
	add_child(bar)
	bar.bind(self)

func current() -> float:
	return _current

func max_health() -> float:
	return _max

func fraction() -> float:
	return 0.0 if _max <= 0.0 else clampf(_current / _max, 0.0, 1.0)

func apply_damage(raw: float, type: StatKeys.DamageType, source: Node) -> void:
	var final_amount := _stats.mitigate_incoming(raw, type)
	_current = clampf(_current - final_amount, 0.0, _max)
	health_changed.emit(_current, _max)
	Events.damage_dealt.emit(source, owner, int(round(final_amount)), type)

func _on_stat_changed(stat: StringName, value: float) -> void:
	if stat == StatKeys.MAX_HEALTH:
		_max = value
		_current = minf(_current, _max)
		health_changed.emit(_current, _max)
```

Notes:
- `owner` in the `Events.damage_dealt.emit(...)` call is `HealthComponent`'s
  own Godot node-owner — same resolution as the old
  `StatsComponent.apply_damage` had (neither `Player.tscn` nor
  `TrainingDummy.tscn` overrides a child's `owner`, so this resolves to the
  scene root exactly as before). No behavior change for anything listening
  to `Events.damage_dealt`.
- `Events` is the existing autoload (`skills/event_bus.gd`) — no import
  needed, same as it wasn't needed in the old `apply_damage`.
- `StatsComponent.of(get_parent())` assumes `HealthComponent` is a direct
  sibling of `StatsComponent` under the same entity root, which is exactly
  how it's wired into both scenes (§7).

---

## 6. `components/health/health_bar.gd` + `health_bar.tscn` (new)

`health_bar.tscn`: bare `Node2D` root, `health_bar.gd` attached, no children.

```gdscript
class_name HealthBar
extends Node2D

const WIDTH := 48.0
const HEIGHT := 6.0
const BACKGROUND := Color(0.5, 0.08, 0.08)
const FOREGROUND := Color(0.2, 0.85, 0.25)

var _fraction: float = 1.0

func _ready() -> void:
	position = Vector2(0, -74)
	visible = false

func bind(health: HealthComponent) -> void:
	health.health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, max: float) -> void:
	if current < max:
		visible = true
	_fraction = 0.0 if max <= 0.0 else clampf(current / max, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-WIDTH / 2.0, 0, WIDTH, HEIGHT), BACKGROUND)
	draw_rect(Rect2(-WIDTH / 2.0, 0, WIDTH * _fraction, HEIGHT), FOREGROUND)

static func fill_width(fraction: float, total_width: float) -> float:
	return clampf(fraction, 0.0, 1.0) * total_width
```

Notes:
- **Green shrinks from the right, red revealed underneath** — both rects
  share the same left edge (`-WIDTH / 2.0`); the green rect's width scales
  with `_fraction` while the red rect stays full width behind it, so as HP
  drops the green edge recedes leftward and red is what's left visible on
  the right. This is the exact visual you described.
- **Hidden until damaged**: starts `visible = false`; the first
  `health_changed` carrying `current < max` flips it on and it stays on
  (never re-hides, including back at full HP from a future heal — no
  regen exists yet so this can't currently happen).
- `WIDTH = 48`, `HEIGHT = 6`, offset `(0, -74)` (10px clear of the 128px-tall
  `CollisionShape2D` both entities share, assuming it's centered on the
  entity origin, which it is in both scenes) are placeholder-but-reasonable
  defaults — tune freely, not load-bearing.
- `fill_width` is a pure static, kept separate from `_draw()` so the width
  math is assertable without rendering — same pattern as `SkillSlot`'s
  `format_seconds`/`keybind_label`/`cooldown_fraction` statics.
- Colors are plain `Color` constants, not a theme resource — no theming
  system exists for world-space nodes yet; restyle freely later.

---

## 7. Scene wiring

### `Player.tscn`

Add a `HealthComponent` node (script `health_component.gd`) as a new child,
sibling to `StatsComponent`. Remove `"health": 100.0` from `StatsComponent`'s
`base_stats` (keep `"max_health": 100.0`):

```
base_stats = {
"jump_velocity": 800.0,
"max_health": 100.0,
"move_speed": 400.0
}
```

### `TrainingDummy.tscn`

Same: add `HealthComponent` as a sibling of `StatsComponent`. Drop
`max_health`/`health` from 999,999 down to **200** — the existing 999,999
value was chosen specifically so damage math never has to think about death
(see the Fireball plan), but it also makes the health bar pixel-invisible on
any real hit. 200 keeps the dummy comfortably un-killable by anything that
exists today (Fireball's 50 damage = 4 hits) while making bar movement
obvious. This is a balance number, not a behavior — tune freely:

```
base_stats = {
"max_health": 200.0
}
```

---

## 8. `skills/projectile/projectile.gd` — call-site change

```gdscript
func _on_body_entered(body: Node) -> void:
	if body == caster:
		return
	var health := HealthComponent.of(body)
	if health != null:
		health.apply_damage(damage, damage_type, caster)
	queue_free()
```

(Replaces `StatsComponent.of(body)` + the stray `print(stats)` debug line —
both go away with this edit.)

---

## 9. Testing (GUT)

### 9.1 `test/components/health/test_health_component.gd` (new)

Mirror `test/components/stats/test_stats_component.gd`'s style — build a real
`StatsComponent` + `HealthComponent` pair under a fake parent node (no
`HealthBar` needed for these; `HealthComponent._ready()` will instance one,
which is harmless in a headless test as long as the node is freed).

```gdscript
extends GutTest

func _make_entity(max_health: float, resist_physical: float = 0.0) -> Node:
	var entity := Node.new()
	var stats := StatsComponent.new()
	stats.name = "StatsComponent"
	stats.base_stats = {
		StatKeys.MAX_HEALTH: max_health,
		StatKeys.resist(StatKeys.damage_type_name(StatKeys.DamageType.PHYSICAL)): resist_physical,
	}
	entity.add_child(stats)
	var health := HealthComponent.new()
	health.name = "HealthComponent"
	entity.add_child(health)
	add_child_autofree(entity)
	return entity

func test_starts_at_max_health():
	var entity := _make_entity(100.0)
	var health := HealthComponent.of(entity)
	assert_eq(health.current(), 100.0)
	assert_eq(health.fraction(), 1.0)

func test_apply_damage_depletes_current_health():
	var entity := _make_entity(100.0)
	var health := HealthComponent.of(entity)
	health.apply_damage(30.0, StatKeys.DamageType.PHYSICAL, null)
	assert_eq(health.current(), 70.0)

func test_apply_damage_uses_stats_component_resistance():
	var entity := _make_entity(100.0, 5.0)
	var health := HealthComponent.of(entity)
	health.apply_damage(100.0, StatKeys.DamageType.PHYSICAL, null)
	# resist clamps to 0.9, so 100 * (1 - 0.9) = 10 damage taken
	assert_eq(health.current(), 90.0)

func test_apply_damage_clamps_at_zero():
	var entity := _make_entity(50.0)
	var health := HealthComponent.of(entity)
	health.apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
	assert_eq(health.current(), 0.0)

func test_health_changed_emits_current_and_max():
	var entity := _make_entity(100.0)
	var health := HealthComponent.of(entity)
	watch_signals(health)
	health.apply_damage(40.0, StatKeys.DamageType.PHYSICAL, null)
	assert_signal_emitted_with_parameters(health, "health_changed", [60.0, 100.0])
```

### 9.2 `test/components/stats/test_stats_component.gd` — update

Replace `test_apply_damage_clamps_resistance_at_0_9` (references a method
that no longer exists) with a `mitigate_incoming` equivalent:

```gdscript
func test_mitigate_incoming_clamps_resistance_at_0_9():
	stats.base_stats = {
		StatKeys.resist(StatKeys.damage_type_name(StatKeys.DamageType.PHYSICAL)): 5.0,
	}
	# resist clamps to 0.9, so 100 * (1 - 0.9) = 10 damage taken
	assert_eq(stats.mitigate_incoming(100.0, StatKeys.DamageType.PHYSICAL), 10.0)
```

### 9.3 `test/library/test_fireball.gd` — update

Both tests currently build a bare `StatsComponent` target and assert via
`StatsComponent.get_stat(StatKeys.HEALTH)`, and reference `StatKeys.HEALTH`
directly — none of that compiles once `StatKeys.HEALTH` is removed. Give the
target (and caster, for the second test) a `HealthComponent` sibling instead,
and assert against it:

```gdscript
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
	target_stats.base_stats = {StatKeys.MAX_HEALTH: 100.0}
	target.add_child(target_stats)
	var target_health := HealthComponent.new()
	target_health.name = "HealthComponent"
	target.add_child(target_health)
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

	assert_eq(target_health.current(), 50.0)
```

Apply the equivalent change to
`test_fireball_projectile_ignores_its_own_caster` — give `caster` a
`HealthComponent` too (`base_stats = {StatKeys.MAX_HEALTH: 100.0}`), and
assert `caster_health.current() == 100.0` in place of the old
`StatsComponent.get_stat` assertion.

---

## 10. Wiring checklist

1. `components/stats/stats_component.gd` — remove `apply_damage`, add
   `mitigate_incoming`, update doc-comment, drop stray `print` (§3).
2. `components/stats/stat_keys.gd` — remove `HEALTH`/`Stat.HEALTH` (§4).
3. `components/health/health_component.gd` — new (§5).
4. `components/health/health_bar.gd` + `health_bar.tscn` — new (§6).
5. `Player.tscn` — add `HealthComponent`, drop `"health"` from `base_stats`
   (§7).
6. `TrainingDummy.tscn` — add `HealthComponent`, set `max_health = 200.0`,
   drop `"health"` (§7).
7. `skills/projectile/projectile.gd` — switch to `HealthComponent.of(body)`
   (§8).
8. `test/components/health/test_health_component.gd` — new (§9.1).
9. `test/components/stats/test_stats_component.gd` — update (§9.2).
10. `test/library/test_fireball.gd` — update (§9.3). Run headless via the
    `godot-gut-tests` skill; must be green.
11. Manual verify: run `main.tscn`. Cast Fireball (`3`) at the Training
    Dummy — bar appears above it at ~75% (200 → 150) after one hit. Let the
    Training Dummy (or anything else) damage the Player, or temporarily cast
    Fireball at the Player, to confirm the Player's own bar appears and
    depletes the same way.

---

## 11. Assumed defaults (flag if you disagree, don't silently change)

- Bar 48×6px, offset `(0, -74)`, colors `Color(0.5, 0.08, 0.08)` /
  `Color(0.2, 0.85, 0.25)` — all placeholder, restyle freely later.
- Training Dummy `max_health = 200.0` — a testing/balance convenience number,
  not a design decision; see §7.
- No death/depleted signal — out of scope per §1 and ADR-0009.
