# Floating Combat Text — implementation handoff

A short-lived number that appears at a character's position when a hit
lands, drifts upward, and fades. Each hit spawns its own independent
instance; there's no pooling, no dedup, no stacking logic.

This document is the complete spec. It is self-contained: an implementer
should not need to re-derive any decision. All decisions below were settled
in a design grill; the "Why" notes exist so you don't reopen them.

---

## 1. Scope

**In:** a new `vfx/floating_combat_text/` pair — `FloatingCombatText` (one
instance, shows a number, animates, frees itself) and `CombatTextSpawner` (a
global `Events.damage_dealt` listener that instances `FloatingCombatText` at
the target's position), wired into `main.tscn`. Fires for every hit, Player
included.

**Out (do not build):** damage-type color coding (plain white/yellow for all
hits right now), critical-hit styling, stacking/merging overlapping numbers,
object pooling (no pooling pattern exists anywhere in the codebase yet — a
fresh node per hit, freed on completion, matches `Projectile`'s existing
lifecycle convention), a "+"/"-" sign prefix, sound.

---

## 2. Architecture

```
vfx/
└── floating_combat_text/
    ├── floating_combat_text.tscn   # Node2D + Label child
    ├── floating_combat_text.gd     # class_name FloatingCombatText
    ├── combat_text_spawner.tscn    # bare Node
    └── combat_text_spawner.gd      # class_name CombatTextSpawner
```

```
main.tscn (Node2D, main.gd)
├── Floor
├── Player
├── SkillBarHUD
├── TrainingDummy
└── CombatTextSpawner        # NEW — connects to Events.damage_dealt itself, no bind() call
```

**Why a new top-level `vfx/` directory:** this is a global, cross-cutting
visual effect triggered by the event bus, owned by no single entity and no
single Skill — it doesn't fit `skills/` (that folder means the
Skill/SkillEffect/Ability system specifically), `components/` (nothing is
attached to a character), or `ui/` (it's a world-space effect, not a
screen-space HUD).

**Why `CombatTextSpawner` connects to `Events` itself instead of being
`bind()`-ed by `main.gd`:** unlike `SkillBar` (which deliberately avoids the
bus because per-character HUD state must not leak across characters —
see `docs/plans/skill-bar-hud.md` §2), combat text is exactly the
cross-cutting case the bus exists for: every hit, on every entity, should
show a number. There's no per-instance state to bind — just drop the node in
`main.tscn` and it works, mirroring how `Events` itself needs no wiring.

**Why a node in `main.tscn` instead of a new autoload:** `Events` is a
passive signal bus with no scene-tree footprint of its own. A spawner needs
an actual parent to instance combat text under so spawned nodes render in
the live game world — an autload doesn't cleanly have one without reaching
for `get_tree().current_scene`, a pattern already known to be awkward (see
the manual-verification notes from the Fireball work).

---

## 3. `vfx/floating_combat_text/floating_combat_text.tscn` + `.gd` (new)

Scene: `Node2D` root (script attached) with one child, `Label`.

On the `Label` node, set in the `.tscn`:
- `theme_override_colors/font_color = Color.WHITE`
- `theme_override_font_sizes/font_size = 20`
- `horizontal_alignment = 1` (`HORIZONTAL_ALIGNMENT_CENTER`)
- `mouse_filter = 2` (`MOUSE_FILTER_IGNORE`) — **required**: a `Label` is a
  `Control` and defaults to intercepting mouse input even outside a
  `CanvasLayer`; without this, floating text sitting over the play area
  would eat clicks/aim input underneath it.

```gdscript
class_name FloatingCombatText
extends Node2D

const RISE_DISTANCE := 40.0
const DURATION := 0.8

@onready var _label: Label = $Label

func play(amount: int) -> void:
	_label.text = str(amount)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)
	tween.parallel().tween_property(_label, "modulate:a", 0.0, DURATION)
	tween.tween_callback(queue_free)
```

Notes:
- Reuses the exact `Label` + `Tween` combo already used throughout
  `SkillSlot` (`play_ready`/`play_fail` in `ui/skill_bar/skill_slot.gd`) —
  `.parallel()` runs the fade alongside the rise, then the plain
  (non-parallel) `tween_callback(queue_free)` runs after both finish. No new
  rendering technique enters the codebase.
- `_label.text` is set synchronously before the tween starts, so `play()` is
  assertable in a test without waiting on the animation (see §5).
- Plain white text, no damage-type coloring — matches the "bare minimum
  first" pattern used for Fireball's own placeholder visual. Layering in a
  `StatKeys.DamageType -> Color` lookup later is a small, additive change to
  this same function.

---

## 4. `vfx/floating_combat_text/combat_text_spawner.tscn` + `.gd` (new)

Scene: bare `Node` root, script attached, no children.

```gdscript
class_name CombatTextSpawner
extends Node

const FLOATING_COMBAT_TEXT := preload("res://vfx/floating_combat_text/floating_combat_text.tscn")

func _ready() -> void:
	Events.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(_source: Node, target: Node, amount: int, _type: StatKeys.DamageType) -> void:
	if not (target is Node2D):
		return
	var instance: FloatingCombatText = FLOATING_COMBAT_TEXT.instantiate()
	add_child(instance)
	instance.global_position = target.global_position
	instance.play(amount)
```

Notes:
- No filtering by Faction or by source — every `damage_dealt` signal spawns
  text, Player-taken-damage included. Simplest option, consistent with
  `StatsComponent`'s symmetric player/enemy damage pipeline (ADR-0002), and
  useful feedback either direction ("I dealt 50" / "I took 30").
- The `target is Node2D` guard is defensive — every damage-capable entity
  today (`Player`, `TrainingDummy`) is a `CharacterBody2D`, so this always
  passes in practice, but `Events.damage_dealt`'s signature only guarantees
  `Node`, not `Node2D`/`global_position`.
- `_source`/`_type` are intentionally unused (no source-based filtering, no
  damage-type coloring yet) — underscore-prefixed per GDScript convention to
  suppress the unused-parameter warning.

---

## 5. Testing (GUT)

### 5.1 `test/vfx/floating_combat_text/test_floating_combat_text.gd` (new)

```gdscript
extends GutTest

func test_play_sets_label_text_to_the_damage_amount():
	var instance: FloatingCombatText = preload("res://vfx/floating_combat_text/floating_combat_text.tscn").instantiate()
	add_child_autofree(instance)
	instance.play(42)
	assert_eq(instance.get_node("Label").text, "42")
```

### 5.2 `test/vfx/floating_combat_text/test_combat_text_spawner.gd` (new)

```gdscript
extends GutTest

func test_damage_dealt_spawns_floating_combat_text_at_target_position():
	var spawner: CombatTextSpawner = preload("res://vfx/floating_combat_text/combat_text_spawner.tscn").instantiate()
	add_child_autofree(spawner)

	var target := Node2D.new()
	target.global_position = Vector2(100, 50)
	add_child_autofree(target)

	Events.damage_dealt.emit(null, target, 50, StatKeys.DamageType.FIRE)

	assert_eq(spawner.get_child_count(), 1)
	var spawned: FloatingCombatText = spawner.get_child(0)
	assert_eq(spawned.global_position, Vector2(100, 50))
	assert_eq(spawned.get_node("Label").text, "50")
```

`Events` resolves fine here — this runs inside GUT's own test-loading
context, which (unlike a raw `-s` custom main-loop script) does register
autoload globals at compile time.

---

## 6. Wiring checklist

1. `vfx/floating_combat_text/floating_combat_text.tscn` + `.gd` — new (§3).
2. `vfx/floating_combat_text/combat_text_spawner.tscn` + `.gd` — new (§4).
3. `main.tscn` — add a `CombatTextSpawner` instance as a new child (no code
   change to `main.gd` needed — it self-wires in `_ready()`).
4. `test/vfx/floating_combat_text/test_floating_combat_text.gd` — new (§5.1).
5. `test/vfx/floating_combat_text/test_combat_text_spawner.gd` — new (§5.2).
   Run headless via the `godot-gut-tests` skill; must be green.
6. Manual verify: run `main.tscn`, cast Fireball (`3`) at the Training
   Dummy — a white "50" should rise from the dummy and fade over ~0.8s. Let
   the dummy or anything else damage the Player and confirm the same happens
   over the Player.

---

## 7. Assumed defaults (flag if you disagree, don't silently change)

- Rise distance 40px, duration 0.8s, font size 20, plain white — all
  placeholder-but-reasonable, tune freely.
- No sound, no damage-type color, no crit styling — explicitly out of scope
  per §1.
