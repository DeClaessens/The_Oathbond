# Mana — implementation handoff

A Mana Resource Pool for casters, spent to activate Skills that carry a mana cost. Mirrors Health's split from ADR-0009 (current value on a component, ceiling as a Stat) but adds regen — a mechanic Health deliberately doesn't have yet.

This document is the complete spec. It is self-contained: an implementer should not need to re-derive any decision. All decisions below were settled in a design grill; the "Why" notes exist so you don't reopen them.

Read ADR-0009 first (Resource Pool vs Stat split), then ADR-0010 (Mana-specific decisions: regen shape, unlimited-mana fallback) and ADR-0011 (Stat enum is append-only) — this doc only covers *how*.

---

## 1. Scope

**In:** a new `components/mana/` pair (`ManaComponent` owns the pool + `spend`/regen, `ManaBar` is the pure view it spawns as a child), added to `Player.tscn`; `MAX_MANA`/`MANA_REGEN` added to `StatKeys` (appended, not inserted — ADR-0011); `Skill.resource_cost` renamed to `mana_cost`; `AbilityComponent` gains mana-affordability gating symmetric with its existing cooldown gating; placeholder `mana_cost` values authored on the three existing Skills; test coverage for `ManaComponent` and the new `AbilityComponent` gating paths.

**Out (do not build):** `TrainingDummy.tscn` (it never casts, no `AbilityComponent`); a regen-delay-after-cast mechanic (ADR-0010 — continuous regen only); an `insufficient_mana` disabled-state on the Skill Bar UI (nothing consumes `skill_failed` for UI feedback yet, same reasoning ADR-0009 used to defer a `died` signal); a `caster_mana` field on `SkillContext` (no `SkillEffect` needs to read or spend Mana directly — `AbilityComponent` owns the debit, mirroring how it alone owns cooldown, not any individual effect); auto-clamping current Mana up when `Max Mana` rises via a future buff (same as Health's existing behavior — the ceiling moves, current value doesn't auto-fill).

---

## 2. Architecture

```
components/mana/
├── mana_component.gd     # class_name ManaComponent, extends Node2D
└── mana_bar.gd            # class_name ManaBar, extends Node2D
```

No `.tscn` wrapper for `ManaComponent` — like `HealthComponent`, it's a bare script attached directly to a `Node2D` in `Player.tscn`. `ManaBar` gets its own `.tscn` (`components/mana/mana_bar.tscn`, a bare `Node2D` root with `mana_bar.gd` attached, no children), instanced by `ManaComponent` in code:

```
Player.tscn
├── ...
├── StatsComponent
├── AbilityComponent
├── HealthComponent
│    └── HealthBar
└── ManaComponent          # NEW — Node2D, mana_component.gd
     └── ManaBar            # spawned in ManaComponent._ready(), not authored in the .tscn
```

`ManaComponent` is a `Node2D`, not a plain `Node`, for the exact reason `HealthComponent` is (see health-bar.md §2): it hosts a `Node2D` child (`ManaBar`) that needs to render at the entity's position, and Godot's 2D transform inheritance breaks if a plain `Node` sits in that chain.

---

## 3. `skills/core/skill.gd` — change

Rename the field. It's currently unread anywhere (dead), so this is a pure rename, not a migration — no authored `.tres` sets it away from its default:

```gdscript
@export var cooldown: float = 1.0
@export var mana_cost: float = 0.0
@export var targeting: Targeting = Targeting.SELF
```

Note the type changes `int` → `float` to match every other numeric Stat/pool value in the codebase (`StatsComponent.get_stat` returns `float`, `HealthComponent` is all `float`) — comparing an `int` cost against `ManaComponent.current(): float` would work via implicit conversion, but there's no reason to keep the mismatch.

---

## 4. `components/stats/stat_keys.gd` — changes

Add the two new constants next to the existing ones:

```gdscript
const MOVE_SPEED    := &"move_speed"
const JUMP_VELOCITY := &"jump_velocity"
const MAX_HEALTH    := &"max_health"
const MAX_MANA      := &"max_mana"
const MANA_REGEN    := &"mana_regen"
```

Append `MAX_MANA` and `MANA_REGEN` to the **end** of `Stat`, after `RESISTANCE` — not next to `MAX_HEALTH` even though that groups more logically. `.tres` files serialize this enum as a raw int (`super_jump.tres` already has `stat = 1` on disk); inserting into the middle would silently repoint that asset at the wrong stat. See ADR-0011.

```gdscript
enum Stat {
    MOVE_SPEED,
    JUMP_VELOCITY,
    MAX_HEALTH,
    OUTGOING_DAMAGE,
    RESISTANCE,
    MAX_MANA,
    MANA_REGEN,
}
```

Add the two new cases to `to_stringname`:

```gdscript
static func to_stringname(stat: Stat, damage_type: DamageType) -> StringName:
    match stat:
        Stat.MOVE_SPEED:      return MOVE_SPEED
        Stat.JUMP_VELOCITY:   return JUMP_VELOCITY
        Stat.MAX_HEALTH:      return MAX_HEALTH
        Stat.OUTGOING_DAMAGE: return dmg(damage_type_name(damage_type))
        Stat.RESISTANCE:      return resist(damage_type_name(damage_type))
        Stat.MAX_MANA:        return MAX_MANA
        Stat.MANA_REGEN:      return MANA_REGEN
    return &""
```

`damage_type` is ignored for both, same as it already is for `MOVE_SPEED`/`JUMP_VELOCITY`/`MAX_HEALTH` — extend the doc-comment above this function to say so.

---

## 5. `components/mana/mana_component.gd` (new)

```gdscript
class_name ManaComponent
extends Node2D

## Owns the current-Mana Resource Pool. Max Mana and Mana Regen are Stats on
## the sibling StatsComponent -- resolved at _ready() and re-read from
## stat_changed if either ever moves (e.g. a future Max Mana buff).

signal mana_changed(current: float, max: float)

var _current: float
var _max: float
var _stats: StatsComponent

static func of(node: Node) -> ManaComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"ManaComponent") as ManaComponent

func _ready() -> void:
    _stats = StatsComponent.of(get_parent())
    if _stats == null:
        push_error("ManaComponent: no sibling StatsComponent found on %s, casting is unconstrained" % get_parent())
        return
    _max = _stats.get_stat(StatKeys.MAX_MANA)
    _current = _max
    _stats.stat_changed.connect(_on_stat_changed)

    var bar: ManaBar = preload("res://components/mana/mana_bar.tscn").instantiate()
    add_child(bar)
    bar.bind(self)

func current() -> float:
    return _current

func max_mana() -> float:
    return _max

func fraction() -> float:
    return 0.0 if _max <= 0.0 else clampf(_current / _max, 0.0, 1.0)

func can_afford(cost: float) -> bool:
    return _current >= cost

func spend(amount: float) -> void:
    _current = clampf(_current - amount, 0.0, _max)
    mana_changed.emit(_current, _max)

func _process(delta: float) -> void:
    if _stats == null or _current >= _max:
        return
    var regen := _stats.get_stat(StatKeys.MANA_REGEN)
    if regen <= 0.0:
        return
    _current = minf(_current + regen * delta, _max)
    mana_changed.emit(_current, _max)

func _on_stat_changed(stat: StringName, value: float) -> void:
    if stat == StatKeys.MAX_MANA:
        _max = value
        _current = minf(_current, _max)
        mana_changed.emit(_current, _max)
```

Notes:
- `can_afford`/`spend` are split (rather than one `try_spend` that both checks and debits) because `AbilityComponent.activate()` needs to check affordability *before* resolving targeting/effects, but only debit *after* every effect succeeds (§6) — two call sites, two moments in time.
- `_process` guards `_current >= _max` first so a full-mana caster doesn't pay a `get_stat` call every frame for nothing.
- Missing `_stats` disables regen the same way it disables `HealthComponent`'s damage path — `push_error` once, `_current`/`_max` stay at their `_ready()`-time zero values, no crash.

---

## 6. `skills/core/ability_component.gd` — changes

`_resolve_activation` gains a `has_enough_mana` parameter, checked in the same position as `is_ready` — before targeting is considered, so a caster that's off cooldown but out of Mana fails the same way an on-cooldown caster does today:

```gdscript
static func _resolve_activation(skill: Skill, is_ready: bool, has_enough_mana: bool, caster: Node, source_position: Vector2, aim_point: Vector2) -> Dictionary:
    if not is_ready:
        return {ok = false, failure_reason = &"on_cooldown", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
    if not has_enough_mana:
        return {ok = false, failure_reason = &"insufficient_mana", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
    match skill.targeting:
        ...
```

`activate()` resolves the caster's `ManaComponent` once, computes affordability (a `null` component means unlimited Mana — ADR-0010), passes it into `_resolve_activation`, and debits only after every effect succeeds — mirroring exactly how `slot.cooldown_remaining` is only set after the effects loop completes without failure:

```gdscript
func activate(index: int, aim_point: Vector2 = Vector2.ZERO) -> void:
    if not _is_valid_slot(index):
        skill_failed.emit(index, &"invalid_slot")
        return
    var slot := slots[index]
    if slot == null:
        skill_failed.emit(index, &"empty_slot")
        return

    var mana := ManaComponent.of(caster)
    var has_enough_mana := mana == null or mana.can_afford(slot.skill.mana_cost)

    var ctx := SkillContext.new()
    ctx.caster = caster
    ctx.caster_stats = StatsComponent.of(caster)
    if caster is Node2D:
        ctx.source_position = (caster as Node2D).global_position
    if caster != null and caster.is_inside_tree():
        ctx.spawn_parent = caster.get_tree().current_scene

    var resolved := _resolve_activation(slot.skill, slot.is_ready(), has_enough_mana, caster, ctx.source_position, aim_point)
    if not resolved.ok:
        skill_failed.emit(index, resolved.failure_reason)
        return
    ctx.targets = resolved.targets
    ctx.aim_direction = resolved.aim_direction

    for effect in slot.skill.effects:
        if not effect.execute(ctx):
            skill_failed.emit(index, &"effect_failed")
            return

    slot.cooldown_remaining = slot.skill.cooldown
    if mana != null:
        mana.spend(slot.skill.mana_cost)
    skill_activated.emit(index, slot.skill)
```

No changes needed to `ability_slot.gd` or `skill_context.gd` — mana lookup/debit stays entirely inside `AbilityComponent`, same locus as cooldown.

---

## 7. `components/mana/mana_bar.gd` + `mana_bar.tscn` (new)

`mana_bar.tscn`: bare `Node2D` root, `mana_bar.gd` attached, no children — identical shape to `health_bar.tscn`.

```gdscript
class_name ManaBar
extends Node2D

const WIDTH := 48.0
const HEIGHT := 6.0
const BACKGROUND := Color(0.08, 0.1, 0.35)
const FOREGROUND := Color(0.25, 0.55, 0.95)

var _fraction: float = 1.0
var _bound_mana: ManaComponent

func _ready() -> void:
    position = Vector2(0, -66)
    visible = true

func bind(mana: ManaComponent) -> void:
    if _bound_mana != null and _bound_mana.mana_changed.is_connected(_on_mana_changed):
        _bound_mana.mana_changed.disconnect(_on_mana_changed)
    _bound_mana = mana
    _fraction = mana.fraction()
    mana.mana_changed.connect(_on_mana_changed)

func _on_mana_changed(current: float, max: float) -> void:
    _fraction = 0.0 if max <= 0.0 else clampf(current / max, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(-WIDTH / 2.0, 0, WIDTH, HEIGHT), BACKGROUND)
    draw_rect(Rect2(-WIDTH / 2.0, 0, fill_width(_fraction, WIDTH), HEIGHT), FOREGROUND)

static func fill_width(fraction: float, total_width: float) -> float:
    return clampf(fraction, 0.0, 1.0) * total_width
```

Notes:
- **Always visible**, unlike `HealthBar`'s hidden-until-damaged rule — Mana depletes routinely during normal play (every cast), so hiding it buys nothing and reads worse than a standard always-on resource bar.
- **Stacked directly below the Health Bar**: `HealthBar` sits at `(0, -74)` with `HEIGHT = 6`; `ManaBar` sits at `(0, -66)`, an 8px gap (6px bar + 2px clear) below it.
- Blue-on-navy palette (`FOREGROUND`/`BACKGROUND`) distinguishes it from Health's green-on-red at a glance; same shrink-from-the-right mechanic (`fill_width`, kept as a pure static for the same testability reason `HealthBar`'s is).
- `bind()` explicitly disconnects any previous binding before rebinding and initializes `_fraction` from `mana.fraction()` immediately (rather than waiting for the first `mana_changed`) — needed because this bar is visible from frame one, unlike `HealthBar`, which can afford to wait since it starts hidden. `HealthBar.bind()` doesn't need either of these; don't backport this pattern there as part of this change, it's outside this doc's scope.

---

## 8. Scene wiring — `Player.tscn`

Add a `ManaComponent` node (script `mana_component.gd`) as a new child, sibling to `StatsComponent`/`AbilityComponent`/`HealthComponent`. Add `max_mana` and `mana_regen` to `StatsComponent.base_stats`:

```
base_stats = {
"jump_velocity": 800.0,
"max_health": 100.0,
"max_mana": 100.0,
"mana_regen": 10.0,
"move_speed": 400.0
}
```

`TrainingDummy.tscn` is untouched — it has no `AbilityComponent` and never casts (§1).

---

## 9. Existing Skills — `mana_cost` values

All three currently default to `0` (free). Author placeholder-but-reasonable non-zero costs so the mechanic is actually exercised in play, not just wired up with nothing spending from the pool. Sized against `cooldown` (a skill already gated by a long cooldown needs less mana gating on top) and against the 100 / 10-per-sec pool (so repeated casts are meaningfully constrained, not either free or instantly draining):

| Skill | Cooldown | `mana_cost` | Why |
|---|---|---|---|
| `fireball.tres` | 0.5s | `20` | Lowest cooldown, the skill players will spam most — mana is the actual limiter here, not cooldown (5 casts drains the pool in 2.5s of spam, ~2s of regen to recover one cast). |
| `super_jump.tres` | 4.0s | `15` | Short buff, moderate cooldown already provides some gating. |
| `sprint.tres` | 20.0s | `10` | Long cooldown already gates this heavily; mana cost is nominal, not the primary constraint. |

Edit each `.tres`'s `[resource]` block to add `mana_cost = <value>` (a plain float line, same as `cooldown`). These are balance numbers, not architecture — tune freely.

---

## 10. Testing (GUT)

### 10.1 `test/components/mana/test_mana_component.gd` (new)

Mirror `test/components/health/test_health_component.gd`'s style:

```gdscript
extends GutTest

func _make_entity(max_mana: float, mana_regen: float = 0.0) -> Node:
    var entity := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {
        StatKeys.MAX_MANA: max_mana,
        StatKeys.MANA_REGEN: mana_regen,
    }
    entity.add_child(stats)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    entity.add_child(mana)
    add_child_autofree(entity)
    return entity

func test_starts_at_max_mana():
    var entity := _make_entity(100.0)
    var mana := ManaComponent.of(entity)
    assert_eq(mana.current(), 100.0)
    assert_eq(mana.fraction(), 1.0)

func test_spend_depletes_current_mana():
    var entity := _make_entity(100.0)
    var mana := ManaComponent.of(entity)
    mana.spend(30.0)
    assert_eq(mana.current(), 70.0)

func test_spend_clamps_at_zero():
    var entity := _make_entity(50.0)
    var mana := ManaComponent.of(entity)
    mana.spend(999.0)
    assert_eq(mana.current(), 0.0)

func test_can_afford_reflects_current_mana():
    var entity := _make_entity(50.0)
    var mana := ManaComponent.of(entity)
    assert_true(mana.can_afford(50.0))
    assert_false(mana.can_afford(50.1))

func test_mana_changed_emits_current_and_max():
    var entity := _make_entity(100.0)
    var mana := ManaComponent.of(entity)
    watch_signals(mana)
    mana.spend(40.0)
    assert_signal_emitted_with_parameters(mana, "mana_changed", [60.0, 100.0])

func test_process_regenerates_at_mana_regen_rate():
    var entity := _make_entity(100.0, 10.0)
    var mana := ManaComponent.of(entity)
    mana.spend(50.0)
    mana._process(1.0)
    assert_eq(mana.current(), 60.0)

func test_process_does_not_regen_past_max():
    var entity := _make_entity(100.0, 10.0)
    var mana := ManaComponent.of(entity)
    mana.spend(5.0)
    mana._process(1.0)
    assert_eq(mana.current(), 100.0)

func test_process_does_not_emit_when_already_at_max():
    var entity := _make_entity(100.0, 10.0)
    var mana := ManaComponent.of(entity)
    watch_signals(mana)
    mana._process(1.0)
    assert_signal_not_emitted(mana, "mana_changed")
```

### 10.2 `test/core/test_ability_component.gd` — additions

`_resolve_activation` now takes `has_enough_mana` as its third positional argument — every existing call site in this file must pass `true` to keep testing what it was already testing:

```gdscript
AbilityComponent._resolve_activation(skill, true, true, caster, Vector2.ZERO, Vector2.ZERO)
```

New tests:

```gdscript
func test_insufficient_mana_fails_before_targeting_is_considered():
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    var result := AbilityComponent._resolve_activation(skill, true, false, caster, Vector2.ZERO, Vector2.ZERO)
    assert_false(result.ok)
    assert_eq(result.failure_reason, &"insufficient_mana")

func test_on_cooldown_takes_priority_over_insufficient_mana():
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    var result := AbilityComponent._resolve_activation(skill, false, false, caster, Vector2.ZERO, Vector2.ZERO)
    assert_eq(result.failure_reason, &"on_cooldown")

func test_activate_with_no_mana_component_casts_for_free():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.mana_cost = 9999.0
    var effect := FakeSkillEffect.new()
    skill.effects = [effect] as Array[SkillEffect]
    abilities.equip(skill, 0)

    watch_signals(abilities)
    abilities.activate(0)

    assert_eq(effect.execute_calls, 1)
    assert_signal_emitted(abilities, "skill_activated")

func test_activate_fails_and_does_not_run_effects_when_mana_is_insufficient():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster_stats.base_stats = {StatKeys.MAX_MANA: 10.0}
    caster.add_child(caster_stats)
    caster.add_child(mana)
    add_child_autofree(caster)

    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.mana_cost = 20.0
    var effect := FakeSkillEffect.new()
    skill.effects = [effect] as Array[SkillEffect]
    abilities.equip(skill, 0)

    watch_signals(abilities)
    abilities.activate(0)

    assert_eq(effect.execute_calls, 0)
    assert_signal_emitted_with_parameters(abilities, "skill_failed", [0, &"insufficient_mana"])

func test_activate_debits_mana_only_after_effects_succeed():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster_stats.base_stats = {StatKeys.MAX_MANA: 100.0}
    caster.add_child(caster_stats)
    caster.add_child(mana)
    add_child_autofree(caster)

    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.mana_cost = 30.0
    var failing := FakeSkillEffect.new()
    failing.succeeds = false
    skill.effects = [failing] as Array[SkillEffect]
    abilities.equip(skill, 0)

    abilities.activate(0)

    assert_eq(mana.current(), 100.0, "mana must not be spent when a cast fails")
```

(`ManaComponent` in this test file needs its `_ready()` to run so `mana.current()` reflects `Max Mana` before any assertion — `add_child_autofree(caster)` after both children are attached ensures that, matching the existing pattern for `caster_stats` elsewhere in this file.)

---

## 11. Wiring checklist

1. `skills/core/skill.gd` — rename `resource_cost` → `mana_cost`, `int` → `float` (§3).
2. `components/stats/stat_keys.gd` — add `MAX_MANA`/`MANA_REGEN` consts, append to `Stat` enum, add `to_stringname` cases (§4).
3. `components/mana/mana_component.gd` — new (§5).
4. `skills/core/ability_component.gd` — `_resolve_activation` gains `has_enough_mana`, `activate()` resolves/checks/debits Mana (§6).
5. `components/mana/mana_bar.gd` + `mana_bar.tscn` — new (§7).
6. `Player.tscn` — add `ManaComponent`, add `max_mana`/`mana_regen` to `base_stats` (§8).
7. `skills/library/fireball.tres`, `super_jump.tres`, `sprint.tres` — add `mana_cost` (§9).
8. `test/components/mana/test_mana_component.gd` — new (§10.1).
9. `test/core/test_ability_component.gd` — update all `_resolve_activation` call sites, add new tests (§10.2).
10. Run headless via the `godot-gut-tests` skill; must be green.
11. Manual verify: run `main.tscn`. Cast Fireball repeatedly — blue bar beneath the health bar drops by 20/100 per cast, refills at 10/sec, and the 6th rapid cast fails silently (no projectile, no cooldown consumed) once Mana is insufficient.

---

## 12. Assumed defaults (flag if you disagree, don't silently change)

- `max_mana = 100.0`, `mana_regen = 10.0` on Player — as specified.
- Mana Bar 48×6px, offset `(0, -66)`, colors `Color(0.08, 0.1, 0.35)` / `Color(0.25, 0.55, 0.95)` — placeholder, restyle freely later.
- `fireball`/`super_jump`/`sprint` mana costs of `20`/`15`/`10` — balance placeholders per §9, not load-bearing.
- No regen-delay-after-cast, no Skill Bar insufficient-mana UI state — both explicitly out of scope per §1.
