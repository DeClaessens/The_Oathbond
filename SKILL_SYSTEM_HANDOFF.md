# Skill System — Implementation Handoff (Oathbond)

## 0. How to read this document

This is a **complete, self-contained build spec** for a composition-based skill
system in the Oathbond Godot 4.7 project. Every architectural decision has
already been made and reviewed — **do not redesign anything.** Your job is to
transcribe these files and wire the integration exactly as written.

The code below is the source of truth. Where a design choice is non-obvious, a
**Rationale** note explains *why* so you don't "fix" it into a bug. The
**Invariants** section at the end lists rules that must never be broken; violating
them causes shared-state bugs, buffs that don't revert, and silent zero-damage.

> This design supersedes an earlier handoff. It differs in ten specific,
> intentional ways (symmetric stats, single scaling seam, flat/add/mult modifier
> buckets, op-defined neutrals, component-owned timed buffs, keyed stacking,
> context-carried caster stats, InputMap actions, a collision-layer convention,
> and a typed `Player`). Those differences are the *point* — build them as
> specified.

---

## 1. Current codebase state (already surveyed — do not re-investigate)

| Thing | Reality |
|---|---|
| Player script | `res://player.gd`, `extends CharacterBody2D`, **no `class_name`** |
| Player scene | `res://Player.tscn`, root node named `CharacterBody2D` (Sprite2D + CollisionShape2D children) |
| Movement values | `const SPEED = 400.0`, `const JUMP_VELOCITY = -800.0` (constants) |
| Input | `_physics_process`, built-in `ui_left`/`ui_right`/`ui_accept` |
| Gravity | `ProjectSettings` `physics/2d/default_gravity = 2948.2` |
| Main scene | `res://main.tscn` → `Main (Node2D)` with `Floor` + player instance |
| Autoload | **none** |
| Skills folder | **none** |
| Collision layers | **no convention** — everything on default layer 1 |
| Enemies | **none exist yet** |
| Engine | Godot **4.7**, Forward+, 2D game |

Because the project is near-empty, nothing constrains the design — but it also
means **you are establishing conventions** (collision layers, stat keys, folder
layout). Follow the ones specified here exactly; other code will depend on them.

---

## 2. Folder layout to create

```
res://skills/
├── event_bus.gd            # autoload, registered as "Events"
├── stats/
│   ├── stat_keys.gd        # typed StringName vocabulary (typo guard)
│   ├── stat_modifier.gd
│   └── stats_component.gd
├── core/
│   ├── skill.gd
│   ├── skill_effect.gd
│   ├── skill_context.gd
│   ├── ability_slot.gd
│   └── ability_component.gd
├── projectile/
│   ├── projectile.gd
│   └── projectile.tscn
├── effects/
│   ├── stat_buff_effect.gd
│   ├── damage_effect.gd
│   └── spawn_projectile_effect.gd
└── library/               # .tres skill assets authored in the editor (empty for now)
```

> Reorganized post-handoff into `stats/`, `core/`, `projectile/` subfolders for
> readability. GDScript resolves everything by `class_name`, not by path, so this
> is a pure filesystem move — only `res://` path strings (autoload registration,
> `.tscn` `ext_resource` paths) needed updating, not any script logic.

---

## 3. The stat & modifier layer

### 3.1 Design in one paragraph (read before the code)

`StatsComponent` is the **single authority on every gameplay number, in both
directions**. Outgoing: a caster's `scale_outgoing(base, type)` scales a skill's
base damage *up* by the caster's offensive modifiers. Incoming:
`apply_damage(...)` scales a hit *down* by the target's resistances. Player and
enemy use the **identical component** — a player can have fire resistance, an
enemy can carry a damage buff. All numbers flow through **one composition
formula**:

```
final = (base + Σ FLAT) × (1 + Σ ADD_PCT) × Π (1 + MULT_PCT)
```

A modifier's **neutral value is defined by its operation**, not by the stat
(`FLAT`→0, `ADD_PCT`→0, `MULT_PCT`→0 which becomes ×1). Consequence: a stat with
**no modifiers collapses to its base**, so there is no per-stat "default 1.0" to
forget and no silent zero-damage trap. Offensive scaling seeds the formula with
the **skill's** base (not a character stat), so "increased fire damage" is purely
a bag of modifiers — nothing to declare on a fresh character.

### 3.2 `stat_keys.gd`

```gdscript
class_name StatKeys
extends RefCounted

## Typo-safe vocabulary for stat StringNames. Reference StatKeys.MOVE_SPEED,
## never a raw &"move_speed" literal — a mistyped raw string is a silent no-op
## that gear/talents/effects would hit constantly. Never instantiated.

const MOVE_SPEED    := &"move_speed"
const JUMP_VELOCITY := &"jump_velocity"     ## stored POSITIVE; applied as -value
const MAX_HEALTH    := &"max_health"
const HEALTH        := &"health"

## Damage-type-scoped keys. dmg_* = outgoing scaling, resist_* = incoming reduction.
static func dmg(type: StringName) -> StringName:
    return StringName("dmg_%s" % type)

static func resist(type: StringName) -> StringName:
    return StringName("resist_%s" % type)
```

### 3.3 `stat_modifier.gd`

```gdscript
class_name StatModifier
extends RefCounted

## One modifier on one named stat. The caller holds the object; StatsComponent
## owns its lifetime once added. Runtime state (remaining) lives HERE, never on a
## Resource. `value` meaning depends on `op` (see below).

enum Op {
    FLAT,       ## value is an absolute amount added to the base
    ADD_PCT,    ## value is a fraction; 0.5 => +50% (additive bucket)
    MULT_PCT,   ## value is a fraction; 0.5 => ×1.5 (multiplicative bucket)
}

## How re-applying a modifier that shares this one's `key` behaves.
enum StackMode {
    REFRESH,    ## reset the duration window; magnitude does NOT compound (implemented)
    STACK,      ## add another independent entry, up to max_stacks   (RESERVED — see §3.5)
}

var stat: StringName
var op: Op = Op.MULT_PCT
var value: float = 0.0

## Grouping tag for timed buffs (e.g. &"sprint"). Empty = ungrouped
## (permanent gear/talent modifiers that never expire and never dedup).
var key: StringName = &""
var stack_mode: StackMode = StackMode.REFRESH
var max_stacks: int = 0          ## 0 = uncapped. RESERVED — used only by STACK mode.

var duration: float = 0.0        ## <= 0 => permanent (never ticked, never expires)
var remaining: float = 0.0       ## runtime; set/decremented by StatsComponent
var source: Object               ## the effect/gear that created it; for debugging
```

### 3.4 `stats_component.gd`

```gdscript
class_name StatsComponent
extends Node

## THE authority on a character's numbers, incoming and outgoing.
## Attach as a child named exactly "StatsComponent" to any character that can
## deal or receive scaled numbers (player AND enemies).
##
## - base_stats holds permanent base values (health, move_speed, ...).
##   NEVER mutate base_stats at runtime for temporary effects — use modifiers.
##   apply_damage is the ONE exception: HP loss is a permanent base change.
## - Modifiers (buffs/debuffs/gear/talents) are added via add_modifier and
##   composed on every get_stat / scale_outgoing call. Movement code must read
##   get_stat() EVERY FRAME — never cache it.

@export var base_stats: Dictionary = {}

var _mods: Array[StatModifier] = []

signal stat_changed(stat: StringName, value: float)

## --- lookup ------------------------------------------------------------

## Resolve the StatsComponent belonging to any node. Single point of coupling
## to the node name — effects and projectiles call this, never a raw path.
static func of(node: Node) -> StatsComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"StatsComponent") as StatsComponent

func get_stat(stat: StringName) -> float:
    return _compose(float(base_stats.get(stat, 0.0)), _mods_for(stat))

## Outgoing scaling: seed the formula with the SKILL's base, not a character
## stat. With no offensive modifiers this returns `base` unchanged. This is the
## single seam to replace when a richer DamagePacket/crit/talent pipeline lands.
func scale_outgoing(base: float, type: StringName) -> float:
    return _compose(base, _mods_for(StatKeys.dmg(type)))

## Shared composition: (base + Σflat) × (1 + Σadd) × Π(1 + mult).
func _compose(base: float, mods: Array[StatModifier]) -> float:
    var flat := 0.0
    var add := 0.0
    var mult := 1.0
    for m in mods:
        match m.op:
            StatModifier.Op.FLAT:     flat += m.value
            StatModifier.Op.ADD_PCT:  add  += m.value
            StatModifier.Op.MULT_PCT: mult *= (1.0 + m.value)
    return (base + flat) * (1.0 + add) * mult

func _mods_for(stat: StringName) -> Array[StatModifier]:
    var out: Array[StatModifier] = []
    for m in _mods:
        if m.stat == stat:
            out.append(m)
    return out

## --- modifiers ---------------------------------------------------------

## Add a modifier. If it carries a `key`, apply the stacking policy:
##   REFRESH (implemented): if a modifier with the same key exists, reset its
##                          remaining window; do NOT add a second entry (no
##                          magnitude compounding). This is Sprint's behavior.
##   STACK   (reserved):    see §3.5 — not yet implemented; asserts loudly.
func add_modifier(mod: StatModifier) -> void:
    if mod.key != &"":
        match mod.stack_mode:
            StatModifier.StackMode.REFRESH:
                var existing := _find_by_key(mod.key)
                if existing != null:
                    existing.remaining = mod.duration    # reset the 5s window
                    stat_changed.emit(existing.stat, get_stat(existing.stat))
                    return
            StatModifier.StackMode.STACK:
                assert(false, "STACK mode not implemented yet — see handoff §3.5")

    mod.remaining = mod.duration
    _mods.append(mod)
    stat_changed.emit(mod.stat, get_stat(mod.stat))

func remove_modifier(mod: StatModifier) -> void:
    if _mods.has(mod):
        _mods.erase(mod)
        stat_changed.emit(mod.stat, get_stat(mod.stat))

func _find_by_key(key: StringName) -> StatModifier:
    for m in _mods:
        if m.key == key:
            return m
    return null

## Remaining time on a keyed buff — for a future cooldown/buff HUD.
func time_remaining(key: StringName) -> float:
    var m := _find_by_key(key)
    return m.remaining if m != null else 0.0

## Tick timed modifiers. Permanent mods (duration <= 0) are never touched.
func _process(delta: float) -> void:
    if _mods.is_empty():
        return
    var expired_stats := {}
    var survivors: Array[StatModifier] = []
    for m in _mods:
        if m.duration <= 0.0:
            survivors.append(m)
            continue
        m.remaining = maxf(0.0, m.remaining - delta)
        if m.remaining > 0.0:
            survivors.append(m)
        else:
            expired_stats[m.stat] = true
    if not expired_stats.is_empty():
        _mods = survivors
        for s in expired_stats:
            stat_changed.emit(s, get_stat(s))

## --- damage ------------------------------------------------------------

## Incoming damage. `raw` is the already-caster-scaled amount. This node is the
## authority on the FINAL value after resistance, so it — and only it — emits the
## damage event. Resistance is treated as a 0..0.9 fraction for now (a seam;
## a future defense pipeline can replace this body).
func apply_damage(raw: float, type: StringName, source: Node) -> void:
    var resist := clampf(get_stat(StatKeys.resist(type)), 0.0, 0.9)
    var final_amount := raw * (1.0 - resist)
    var hp := float(base_stats.get(StatKeys.HEALTH, 0.0))
    hp = maxf(0.0, hp - final_amount)
    base_stats[StatKeys.HEALTH] = hp
    stat_changed.emit(StatKeys.HEALTH, hp)
    if Engine.has_singleton("Events") or (typeof(Events) != TYPE_NIL):
        Events.damage_dealt.emit(source, owner, int(round(final_amount)), type)
```

> **Rationale — `owner` as the victim:** `owner` is the scene root the component
> is saved under (the `Player`/enemy node), because components are authored *in*
> the character scene. If you ever add a `StatsComponent` to a node purely from
> code, set `owner` or emit the parent explicitly.

> **Rationale — the `Events` guard:** `Events` is an autoload and always exists
> once registered, but the guard keeps `StatsComponent` usable in isolated unit
> scenes/tests where the autoload isn't present.

### 3.5 STACK mode — reserved, DO NOT build yet

`STACK` is intentionally unimplemented and asserts if used. It is designed-for so
adding it later is not a rewrite:

- The `_mods` list already **allows multiple entries sharing one `key`**, each
  with its own `remaining` — that *is* the "list of independent per-stack timers"
  the stacking design requires.
- To implement later: in `add_modifier`'s `STACK` branch, count entries with the
  matching key, append if under `max_stacks`, and reset each. Add an
  `expiry_mode: DROP_ONE | DROP_ALL` to decide whether one stack falls off per
  timer or the whole group drops together. **No structural change to `_mods`.**

Leave the `assert(false, ...)` in place until the stacking design is scheduled.

---

## 4. The skill core (pure, untouched when adding skills)

### 4.1 `skill.gd`

```gdscript
class_name Skill
extends Resource

## Pure data: metadata + a list of composable effects. Author as .tres in the
## editor or construct in code. NEVER store runtime state here — Resources are
## shared across every character that equips them.

enum Targeting { SELF, ALLY, ENEMY, AREA, NONE }

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_multiline var description: String

@export var cooldown: float = 1.0
@export var resource_cost: int = 0
@export var targeting: Targeting = Targeting.SELF   ## declarative hint; caller resolves targets

@export var effects: Array[SkillEffect] = []
```

### 4.2 `skill_effect.gd`

```gdscript
class_name SkillEffect
extends Resource

## Base class for one unit of skill behavior. Subclass and override execute().
## Adding behavior = adding a subclass. Never modify Skill, AbilityComponent, or
## any character script to add new skill behavior. Effects use ONLY the
## SkillContext — they never reach into the scene tree to find their own targets.

func execute(_ctx: SkillContext) -> void:
    push_error("SkillEffect.execute() not overridden by %s" % get_class())
```

### 4.3 `skill_context.gd`

```gdscript
class_name SkillContext
extends RefCounted

## Carrier passed to every effect on activation. Everything an effect needs must
## be in here. caster_stats is resolved ONCE by AbilityComponent so effects never
## look it up themselves.

var caster: Node
var caster_stats: StatsComponent           ## resolved by AbilityComponent
var targets: Array[Node] = []
var source_position: Vector2
var aim_direction: Vector2                  ## directional/projectile skills
```

### 4.4 `ability_slot.gd`

```gdscript
class_name AbilitySlot
extends RefCounted

## Runtime wrapper around one equipped Skill. Cooldown lives HERE, not on the
## Skill resource, so two characters sharing a Skill.tres have independent
## cooldowns.

var skill: Skill
var cooldown_remaining: float = 0.0

func is_ready() -> bool:
    return cooldown_remaining <= 0.0

func tick(delta: float) -> void:
    cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
```

### 4.5 `ability_component.gd`

```gdscript
class_name AbilityComponent
extends Node

## Attach to any character (player or enemy — identical code). Owns 4 equipped
## slots, ticks cooldowns, resolves the caster context, fires effects. Signals
## travel UP to whoever owns the character; this node never reaches into UI/audio.

signal skill_activated(index: int, skill: Skill)
signal skill_failed(index: int, reason: StringName)
signal cooldown_changed(index: int, remaining: float, total: float)

const SLOT_COUNT := 4

var caster: Node                    ## set by the owner character in _ready
var slots: Array[AbilitySlot] = []

func _ready() -> void:
    slots.resize(SLOT_COUNT)

func equip(skill: Skill, index: int) -> void:
    assert(index >= 0 and index < SLOT_COUNT, "slot index out of range")
    var slot := AbilitySlot.new()
    slot.skill = skill
    slots[index] = slot

func unequip(index: int) -> void:
    slots[index] = null

func _process(delta: float) -> void:
    for i in slots.size():
        var slot := slots[i]
        if slot != null and slot.cooldown_remaining > 0.0:
            slot.tick(delta)
            cooldown_changed.emit(i, slot.cooldown_remaining, slot.skill.cooldown)

## Self-targeted or explicit-target skills. `targets` is the resolved array the
## CALLER wants affected (invariant: effects never resolve their own targets).
func try_activate(index: int, targets: Array[Node], ctx: SkillContext = null) -> void:
    var slot := slots[index]
    if slot == null:
        skill_failed.emit(index, &"empty_slot")
        return
    if not slot.is_ready():
        skill_failed.emit(index, &"on_cooldown")
        return

    if ctx == null:
        ctx = SkillContext.new()
        ctx.targets = targets
    ctx.caster = caster
    ctx.caster_stats = StatsComponent.of(caster)     ## resolved ONCE, here
    if caster is Node2D:
        ctx.source_position = (caster as Node2D).global_position

    for effect in slot.skill.effects:
        effect.execute(ctx)

    slot.cooldown_remaining = slot.skill.cooldown
    skill_activated.emit(index, slot.skill)

## Directional skills (projectiles/cones/rays). Caller supplies the direction.
func activate_with_direction(index: int, direction: Vector2) -> void:
    var ctx := SkillContext.new()
    ctx.aim_direction = direction
    try_activate(index, [], ctx)
```

---

## 5. Effects (each new behavior is a new subclass)

### 5.1 `effects/stat_buff_effect.gd`

```gdscript
class_name StatBuffEffect
extends SkillEffect

## Applies a timed (or permanent) stat modifier to each target, then hands
## lifetime to the target's StatsComponent — NO await here. A speed buff and a
## jump buff are the same class, different data. Set duration <= 0 for permanent.

@export var stat: StringName = &"move_speed"
@export var op: StatModifier.Op = StatModifier.Op.MULT_PCT
@export var value: float = 0.5                                   ## +50% for MULT/ADD; absolute for FLAT
@export var duration: float = 5.0
@export var key: StringName = &""                               ## grouping tag; enables REFRESH dedup
@export var stack_mode: StatModifier.StackMode = StatModifier.StackMode.REFRESH

func execute(ctx: SkillContext) -> void:
    for target in ctx.targets:
        var stats := StatsComponent.of(target)
        if stats == null:
            push_warning("StatBuffEffect: %s has no StatsComponent" % target)
            continue
        var mod := StatModifier.new()
        mod.stat = stat
        mod.op = op
        mod.value = value
        mod.duration = duration
        mod.key = key
        mod.stack_mode = stack_mode
        mod.source = self
        stats.add_modifier(mod)
```

### 5.2 `effects/damage_effect.gd`

```gdscript
class_name DamageEffect
extends SkillEffect

## Instantly damages every target. Scales the base by the CASTER's offensive
## stats (single seam) at cast time, then lets each target's StatsComponent apply
## resistance and emit the event. This effect never emits damage events itself.

@export var base_amount: int = 50
@export var damage_type: StringName = &"physical"

func execute(ctx: SkillContext) -> void:
    var scaled := float(base_amount)
    if ctx.caster_stats != null:
        scaled = ctx.caster_stats.scale_outgoing(base_amount, damage_type)
    for target in ctx.targets:
        var stats := StatsComponent.of(target)
        if stats == null:
            continue
        stats.apply_damage(scaled, damage_type, ctx.caster)
```

### 5.3 `effects/spawn_projectile_effect.gd`

```gdscript
class_name SpawnProjectileEffect
extends SkillEffect

## Instantiates a projectile and launches it along ctx.aim_direction. Outgoing
## scaling is SNAPSHOT at cast time (caster's buffs bake into the projectile's
## damage), which is the standard behavior for fire-and-forget projectiles.
## Use AbilityComponent.activate_with_direction() to populate aim_direction.

@export var projectile_scene: PackedScene
@export var speed: float = 600.0
@export var base_damage: int = 50
@export var damage_type: StringName = &"fire"

func execute(ctx: SkillContext) -> void:
    if projectile_scene == null:
        push_warning("SpawnProjectileEffect: projectile_scene is null")
        return

    var scaled := float(base_damage)
    if ctx.caster_stats != null:
        scaled = ctx.caster_stats.scale_outgoing(base_damage, damage_type)

    var p := projectile_scene.instantiate() as Projectile
    p.caster      = ctx.caster
    p.direction   = ctx.aim_direction
    p.speed       = speed
    p.damage      = scaled           ## already caster-scaled
    p.damage_type = damage_type

    ctx.caster.get_tree().current_scene.add_child(p)
    p.global_position = ctx.source_position
```

---

## 6. `projectile.gd` + `projectile.tscn`

### 6.1 `projectile.gd`

```gdscript
class_name Projectile
extends Area2D

## Self-contained projectile. Moves in a direction, damages the first valid
## StatsComponent-bearing body it overlaps, frees itself. Also self-frees after
## `lifetime` seconds (safety net for off-screen misses — with no enemies yet it
## simply flies and expires, which is correct).
##
## `damage` arrives ALREADY caster-scaled from SpawnProjectileEffect; the target
## still applies resistance in apply_damage.
##
## Scene setup (see §6.2): CollisionShape2D, collision_layer = PlayerProjectile,
## collision_mask = World | Enemy, body_entered -> _on_body_entered.

var caster: Node
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: float = 50.0
var damage_type: StringName = &"physical"

@export var lifetime: float = 3.0

func _ready() -> void:
    get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
    if body == caster:
        return
    var stats := StatsComponent.of(body)
    if stats != null:
        stats.apply_damage(damage, damage_type, caster)
    queue_free()
```

### 6.2 `projectile.tscn` (author in editor)

```
Projectile (Area2D)          ← script: projectile.gd
└── CollisionShape2D         ← CircleShape2D or RectangleShape2D sized to the visual
```

- `Projectile.collision_layer` → **PlayerProjectile** (L4, bit value 8)
- `Projectile.collision_mask`  → **World** (L1, bit 1) **| Enemy** (L3, bit 4) → mask = 5
- In the node's Signals tab, connect **`body_entered`** → **`_on_body_entered`**.
- Optionally add a Sprite2D/visual; not required for logic.

---

## 7. `event_bus.gd` (autoload `Events`)

```gdscript
extends Node

## Global bus for CROSS-CUTTING concerns only: floating damage numbers, audio,
## screen shake, quest tracking, analytics. If exactly one system cares about a
## signal, put it on the relevant node instead (e.g. AbilityComponent's local
## signals). Test: if you deleted Events, only genuinely cross-cutting features
## should break.

signal damage_dealt(source: Node, target: Node, amount: int, type: StringName)
signal status_applied(target: Node, status: StringName, duration: float)
signal skill_cast(caster: Node, skill: Skill)
```

**Register the autoload:** Project → Project Settings → Globals/Autoload → add
`res://skills/event_bus.gd` with node name **`Events`**, enabled. This appends to
`project.godot`:

```ini
[autoload]
Events="*res://skills/event_bus.gd"
```

---

## 8. `project.godot` — InputMap actions & collision-layer names

Add via Project Settings (or edit the file). **Input Map** — add these actions
(suggested default bindings in brackets; rebind freely):

| Action | Default key |
|---|---|
| `move_left` | A / Left |
| `move_right` | D / Right |
| `jump` | Space |
| `skill_1` | 1 |
| `skill_2` | 2 |
| `skill_3` | 3 |
| `skill_4` | 4 |

**2D physics layer names** (Project Settings → Layer Names → 2D Physics):

| Layer | Name | Bit value |
|---|---|---|
| 1 | World | 1 |
| 2 | Player | 2 |
| 3 | Enemy | 4 |
| 4 | PlayerProjectile | 8 |
| 5 | EnemyProjectile | 16 |

Resulting `project.godot` additions look like:

```ini
[layer_names]
2d_physics/layer_1="World"
2d_physics/layer_2="Player"
2d_physics/layer_3="Enemy"
2d_physics/layer_4="PlayerProjectile"
2d_physics/layer_5="EnemyProjectile"
```

---

## 9. Integration — the player scene & script

### 9.1 Scene changes (`Player.tscn`)

1. **Rename the root node** `CharacterBody2D` → `Player`.
2. Set the root's `collision_layer` = **Player (L2, value 2)**, `collision_mask`
   = **World (L1, value 1)**.
3. Add two child nodes (type `Node`), named **exactly**:
   - `StatsComponent` → attach `stats_component.gd`
   - `AbilityComponent` → attach `ability_component.gd`
4. Select `StatsComponent` and fill `base_stats` in the Inspector:

```
base_stats = {
    "move_speed": 400.0,
    "jump_velocity": 800.0,      # POSITIVE; script applies -value
    "max_health": 100.0,
    "health": 100.0
}
```

> The original `SPEED = 400`, `JUMP_VELOCITY = -800`. Store `jump_velocity` as the
> positive magnitude `800`; the script negates it (`velocity.y = -get_stat(...)`).

Also set **`Floor`** (in `Floor.tscn` or `main.tscn`) to `collision_layer` =
**World (1)** so the player and projectiles interact with it.

> `main.tscn` references the player scene by `uid`, so renaming the root node does
> not break the instance — but re-save `main.tscn` in the editor after the rename.

### 9.2 `player.gd` — full rewrite

```gdscript
class_name Player
extends CharacterBody2D

@onready var stats: StatsComponent = $StatsComponent
@onready var abilities: AbilityComponent = $AbilityComponent

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
    abilities.caster = self
    abilities.equip(_make_sprint_skill(), 0)
    abilities.equip(_make_super_jump_skill(), 1)
    # slot 2/3 reserved: projectile / enemy-targeted, wired when enemies exist

    # Optional but recommended while integrating — see cooldown feedback live:
    abilities.skill_failed.connect(func(i, reason): print("skill %d failed: %s" % [i, reason]))

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    if Input.is_action_just_pressed(&"jump") and is_on_floor():
        velocity.y = -stats.get_stat(StatKeys.JUMP_VELOCITY)      # read EVERY frame

    var direction := Input.get_axis(&"move_left", &"move_right")
    var speed := stats.get_stat(StatKeys.MOVE_SPEED)              # read EVERY frame
    if direction:
        velocity.x = direction * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed)

    move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"skill_1"):
        abilities.try_activate(0, [self])
    elif event.is_action_pressed(&"skill_2"):
        abilities.try_activate(1, [self])
    elif event.is_action_pressed(&"skill_3"):
        # directional example for when a projectile skill is equipped in slot 2
        var dir := (get_global_mouse_position() - global_position).normalized()
        abilities.activate_with_direction(2, dir)
    elif event.is_action_pressed(&"skill_4"):
        abilities.try_activate(3, [self])   # placeholder until enemy targeting exists

## --- starting loadout (code-built; swap to load("res://skills/library/*.tres") later) ---

func _make_sprint_skill() -> Skill:
    var eff := StatBuffEffect.new()
    eff.stat = StatKeys.MOVE_SPEED
    eff.op = StatModifier.Op.MULT_PCT
    eff.value = 0.5                       # +50%  => ×1.5
    eff.duration = 5.0
    eff.key = &"sprint"
    eff.stack_mode = StatModifier.StackMode.REFRESH
    var s := Skill.new()
    s.id = &"sprint"
    s.display_name = "Sprint"
    s.cooldown = 20.0
    s.targeting = Skill.Targeting.SELF
    s.effects = [eff] as Array[SkillEffect]
    return s

func _make_super_jump_skill() -> Skill:
    var eff := StatBuffEffect.new()
    eff.stat = StatKeys.JUMP_VELOCITY
    eff.op = StatModifier.Op.MULT_PCT
    eff.value = 0.6                       # +60%  => ×1.6
    eff.duration = 3.0
    eff.key = &"super_jump"
    eff.stack_mode = StatModifier.StackMode.REFRESH
    var s := Skill.new()
    s.id = &"super_jump"
    s.display_name = "Super Jump"
    s.cooldown = 4.0
    s.targeting = Skill.Targeting.SELF
    s.effects = [eff] as Array[SkillEffect]
    return s
```

### 9.3 Enemies (when they exist — not now)

Any node damageable by `DamageEffect`/`Projectile` needs a child named exactly
`StatsComponent` with at least `health` in `base_stats`, and its body on the
**Enemy (L3)** collision layer. No enemy scene exists yet; leave this as a note.

---

## 10. Verification checklist

Run `main.tscn` and confirm:

- [ ] No errors/warnings in Output on startup.
- [ ] Player moves left/right (`move_left`/`move_right`) and jumps (`jump`) —
      base `move_speed` 400, `jump_velocity` 800 behave like the old constants.
- [ ] Press **`skill_1`** (Sprint): horizontal speed jumps to ×1.5 for **5s**,
      then reverts. `Events` / no errors.
- [ ] Re-press `skill_1` **during** the 5s window while off cooldown: the window
      **resets to 5s**, speed does **not** stack higher (REFRESH proof).
- [ ] Press `skill_1` while on cooldown (within 20s): prints `skill 0 failed:
      on_cooldown`.
- [ ] Press **`skill_2`** (Super Jump): next jump is noticeably higher (×1.6) for
      3s, then reverts.
- [ ] `StatsComponent.get_stat(StatKeys.MOVE_SPEED)` returns `400.0` at rest
      (no accidental zero — confirms op-defined neutrals).

---

## 11. Invariants — never violate these

1. **No runtime state on a `Resource`.** `Skill`/`SkillEffect` are shared. Cooldown
   lives on `AbilitySlot`; modifier lifetime lives on `StatModifier`/`StatsComponent`.
2. **Effects use only `SkillContext`.** No `get_tree()`/`get_node()`/globals to
   resolve targets. The caller resolves targets and passes them in. The sole
   allowed scene reach is `SpawnProjectileEffect` adding its projectile to the
   scene — it *writes*, never *reads* scene state.
3. **The authority on the final number emits the event.** `StatsComponent.apply_damage`
   knows the value after resistance, so it emits `Events.damage_dealt`. `DamageEffect`
   and `Projectile` never emit damage events.
4. **Movement reads `get_stat()` every frame.** Never cache a stat across frames —
   the modifier system only reflects buff apply/expiry because `get_stat` recomposes.
5. **Signals travel upward.** `AbilityComponent` emits; UI/audio connect to it. The
   component never holds or calls into UI. `$HUD.update()` inside it is wrong —
   connect from the HUD side.
6. **`Events` is cross-cutting only.** A signal exactly one system consumes belongs
   on a node, not on `Events`.
7. **Neutral comes from the op, base comes from the source.** Never reintroduce a
   per-stat "default 1.0". `get_stat` seeds with `base_stats`; `scale_outgoing`
   seeds with the skill base; a stat with no mods must equal its base.
8. **`StatsComponent` is resolved via `StatsComponent.of()` and the child is named
   exactly `StatsComponent`.** No raw `get_node("StatsComponent")` strings scattered
   in effects.

---

## 12. Extending the system later (no core edits)

- **New buff/debuff:** author a `Skill` .tres with a `StatBuffEffect` sub-resource;
  set `stat`/`op`/`value`/`duration`/`key`. Zero code.
- **New damage pattern:** subclass `SkillEffect`, override `execute()`. Core
  untouched.
- **New projectile behavior** (homing/bouncing/splitting): new scene extending
  `Area2D` with its own `_physics_process`; assign to
  `SpawnProjectileEffect.projectile_scene`.
- **Multi-effect skill:** add several effects to `Skill.effects`; `try_activate`
  loops them (e.g. `DamageEffect` + a burning `StatBuffEffect`).
- **Stacking buffs (STACK mode):** implement the reserved branch in
  `add_modifier` + add `expiry_mode`; `_mods` structure already supports it (§3.5).
- **Talents / gear / crit / DamagePacket:** they become `StatModifier`s (for
  passive stat changes) or a replacement body for `scale_outgoing` (for a full
  offensive pipeline). `scale_outgoing` is the single seam — effects don't change.
- **Enemy-targeted / AREA skills:** build target resolution in the *caller*
  (player input / AI), pass resolved nodes into `try_activate`. The `Targeting`
  enum on `Skill` is the declarative hint to drive that resolution.

---

## 13. Inspector-facing `Stat`/`DamageType` enums (grilled post-handoff)

### 13.1 Problem

`StatModifier.stat`, `StatBuffEffect.stat`, `DamageEffect.damage_type`, and
`SpawnProjectileEffect.damage_type` were raw `StringName` fields. A designer
hand-typing `"move_speeed"` into the Inspector gets a silent no-op — no error,
no warning, just a buff that does nothing. Worse, `DamageEffect`/
`SpawnProjectileEffect.damage_type` had **no enumeration anywhere** — pure
freeform string, the single biggest typo surface in the system.

### 13.2 Decision: enum-as-authoring-layer, not enum-as-runtime

The runtime is **not** changing. `StatsComponent.base_stats`, `get_stat()`,
`scale_outgoing()`, `apply_damage()`, and `StatModifier.stat` all stay
`StringName`-keyed, exactly as built. Only the three Inspector-editable
`SkillEffect` subclasses (`StatBuffEffect`, `DamageEffect`,
`SpawnProjectileEffect`) change — their exported fields become enums, and a
converter turns the enum pick into the same `StringName` the engine has
always used.

**Rejected alternative — enum-native runtime:** retyping `base_stats`/
`StatModifier.stat`/`get_stat()` to take the enum directly. Rejected for two
concrete reasons:
1. **Serialization fragility.** `.tres` files store enum fields as raw ints
   (see `sprint.tres`: `op = 2`). If `Stat` were threaded into the runtime and
   someone later inserts a new entry in the middle of the enum, every
   existing `.tres` silently starts pointing at the wrong stat — no error,
   just a plausible-looking wrong number. `StringName` has no such
   positional dependency.
2. **`dmg_<type>`/`resist_<type>` are composed, not enumerable**, without a
   combinatorial `DMG_FIRE`/`RESIST_FIRE`/`DMG_ICE`/... enum that has to stay
   in lockstep with `DamageType` by hand.

### 13.3 The enums (`res://skills/stats/stat_keys.gd`)

```gdscript
enum Stat {
    MOVE_SPEED,
    JUMP_VELOCITY,
    MAX_HEALTH,
    HEALTH,
    OUTGOING_DAMAGE,   ## compound — pair with a DamageType; means dmg_<type>
    RESISTANCE,        ## compound — pair with a DamageType; means resist_<type>
}

enum DamageType {
    PHYSICAL,
    FIRE,
}
```

Minimal `DamageType` palette on purpose — only the two types that already
appear in code. Adding `ICE`/`LIGHTNING`/etc. later is a one-line enum
addition + one `match` arm; this is simply what a closed enum is, not a
deferred cost.

### 13.4 Converter (also in `stat_keys.gd`)

```gdscript
static func to_stringname(stat: Stat, damage_type: DamageType = DamageType.PHYSICAL) -> StringName:
    match stat:
        Stat.MOVE_SPEED:      return MOVE_SPEED
        Stat.JUMP_VELOCITY:   return JUMP_VELOCITY
        Stat.MAX_HEALTH:      return MAX_HEALTH
        Stat.HEALTH:          return HEALTH
        Stat.OUTGOING_DAMAGE: return dmg(damage_type_name(damage_type))
        Stat.RESISTANCE:      return resist(damage_type_name(damage_type))
    return &""

static func damage_type_name(type: DamageType) -> StringName:
    match type:
        DamageType.PHYSICAL: return &"physical"
        DamageType.FIRE:     return &"fire"
    return &"physical"
```

`StatKeys.MOVE_SPEED`/`JUMP_VELOCITY`/etc. (the existing `StringName`
constants) are unchanged and remain what runtime code (e.g. `player.gd`'s
`stats.get_stat(StatKeys.JUMP_VELOCITY)`) uses directly. The enums are a
parallel, Inspector-facing vocabulary that resolves back down to those same
constants — not a replacement for them.

### 13.5 Field changes

- `stat_buff_effect.gd`: `stat: StringName` → `stat: StatKeys.Stat`. New field
  `damage_type: StatKeys.DamageType` (always visible in the Inspector, per
  §13.6 below; meaningless unless `stat` is `OUTGOING_DAMAGE`/`RESISTANCE`).
  `execute()` calls `StatKeys.to_stringname(stat, damage_type)` instead of
  assigning `stat` straight through.
- `damage_effect.gd` / `spawn_projectile_effect.gd`: `damage_type: StringName`
  → `damage_type: StatKeys.DamageType`. `execute()` converts once via
  `StatKeys.damage_type_name(damage_type)` before calling `scale_outgoing`/
  `apply_damage`.
- `stat_modifier.gd`, `stats_component.gd`, `skill.gd`, `ability_component.gd`,
  `projectile.gd`, `player.gd` — **untouched**. `StatModifier` is never
  authored directly in the Inspector (only built in code by `StatBuffEffect`),
  so it never needed the enum treatment.

### 13.6 Rejected: conditional field visibility

`damage_type` is always visible on `StatBuffEffect`, even when `stat` is
`MOVE_SPEED` (where it's simply ignored). Hiding it conditionally would need
`@tool` + `_validate_property()`/`_get_property_list()` overrides — real
added complexity for a cosmetic win. Deferred; nothing about the runtime
shape needs to change to add it later.

### 13.7 Fallout: existing `.tres` assets need regenerating

`sprint.tres`/`super_jump.tres` were saved with `stat` as a raw `StringName`
(`&"move_speed"`). Since the field type changes to an enum, these are
regenerated the same way they were built the first time — construct in code,
`ResourceSaver.save()` — not hand-edited.
