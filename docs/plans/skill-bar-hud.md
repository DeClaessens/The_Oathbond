# Skill Bar HUD — implementation handoff

A read-only on-screen bar that reflects the player's four Ability Slots: which
Skills are equipped, which slots are open, and each slot's live cooldown state.
Triggering is unchanged (keys 1–4 → `AbilityComponent.activate`); the bar only
reflects state.

This document is the complete spec. It is self-contained: an implementer should
not need to re-derive any decision. All decisions below were settled in a design
grill; the "Why" notes exist so you don't reopen them.

---

## 1. Scope

**In:** a `SkillBar` HUD showing 4 slots (2 filled, 2 empty today), radial
cooldown feedback with a seconds numeral, a "ready again" flash, and a shake/tint
on a failed cast.

**Out (do not build):** click-to-activate, drag-and-drop equipping, a Known
Skills / loadout editor panel, resource-cost display, real icon art. The
`slot_changed` signal is the seam a future loadout editor will use — that's the
only forward hook we add now.

---

## 2. Architecture & data flow

```
main.tscn (Node2D, main.gd)
├── Floor
├── Player (player.gd)
│    └── AbilityComponent  ── signals ──┐
└── SkillBarHUD (CanvasLayer, skill_bar.gd)
     └── HBoxContainer
          ├── SkillSlot (0)   ◄─────────┘  bound in main.gd:
          ├── SkillSlot (1)               hud.bind(player.abilities)
          ├── SkillSlot (2)
          └── SkillSlot (3)
```

- The HUD **binds directly** to the player's `AbilityComponent` and listens to
  its per-component signals. We do **not** route through the `Events` autoload —
  that bus is for cross-cutting game events; enemies also have an
  `AbilityComponent` and must not spam the HUD. Direct binding keeps the data
  source explicit and the component reusable.
- Wiring happens in a **new `main.gd` composition root**, not inside the HUD or
  the Player. Keeps cross-node wiring in one obvious place and lets the HUD be
  unit-tested against a fake component.

### Node `_ready` ordering (already correct — rely on it)

Children `_ready` before parents. `Player._ready()` equips Sprint→0,
SuperJump→1 and `SkillBar._ready()` builds its 4 empty slot views, both **before**
`Main._ready()` calls `hud.bind(...)`. So `bind()` can safely read
`abilities.slots` for the initial paint. Do not add deferred-call hacks; the
order holds because both are children of `Main`.

---

## 3. Core change: `AbilityComponent.slot_changed`

File: `skills/core/ability_component.gd`. Add one signal and emit it from the two
mutators. `skill == null` means the slot was emptied.

```gdscript
signal skill_activated(index: int, skill: Skill)
signal skill_failed(index: int, reason: StringName)
signal cooldown_changed(index: int, remaining: float, total: float)
signal slot_changed(index: int, skill: Skill)   # NEW — skill == null when emptied

func equip(skill: Skill, index: int) -> void:
	assert(index >= 0 and index < SLOT_COUNT, "slot index out of range")
	var slot := AbilitySlot.new()
	slot.skill = skill
	slots[index] = slot
	slot_changed.emit(index, skill)              # NEW

func unequip(index: int) -> void:
	slots[index] = null
	slot_changed.emit(index, null)               # NEW
```

Nothing else in the component changes. The existing cooldown chain is already
complete: `activate()` sets `cooldown_remaining` and emits `skill_activated`;
`_process` emits `cooldown_changed` every frame while `remaining > 0`, including
the final tick where `remaining` reaches exactly `0.0` — that terminal frame is
the HUD's "ready again" trigger.

---

## 4. Composition root: `main.gd` (new)

Attach to the `Main` node in `main.tscn`.

```gdscript
extends Node2D

@onready var player: Player = $Player
@onready var hud: SkillBar = $SkillBarHUD

func _ready() -> void:
	hud.bind(player.abilities)
```

---

## 5. `ui/skill_bar/` — files to create

```
ui/
└── skill_bar/
    ├── skill_bar.tscn      # CanvasLayer > MarginContainer > HBoxContainer
    ├── skill_bar.gd        # class_name SkillBar
    ├── skill_slot.tscn     # one slot view
    └── skill_slot.gd       # class_name SkillSlot
```

### 5.1 `skill_bar.tscn` / `skill_bar.gd` (`class_name SkillBar`)

Scene: root `CanvasLayer` named `SkillBarHUD`. Child `MarginContainer` anchored
to the **bottom-center** (anchor preset "bottom wide" or center-bottom), holding
an `HBoxContainer` with a few px `theme_override_constants/separation`. The HBox
is where slot instances are added.

Responsibilities:

- `_ready()`: instance `AbilityComponent.SLOT_COUNT` (`= 4`) `SkillSlot`s into the
  HBox, assigning each its index (0..3). `SLOT_COUNT` is a const — read it, never
  hardcode 4.
- `func bind(abilities: AbilityComponent) -> void`:
  - store the reference,
  - connect `skill_activated`, `cooldown_changed`, `skill_failed`, `slot_changed`,
  - **initial paint:** for each `i in SLOT_COUNT`, read `abilities.slots[i]` and
    call the matching slot's `set_skill(slot.skill if slot else null)` and, if
    `slot and slot.cooldown_remaining > 0.0`,
    `set_cooldown(slot.cooldown_remaining, slot.skill.cooldown)`.
- Signal routing (each just forwards to the slot at `index`):
  - `skill_activated(i, skill)` → `slots[i].begin_cooldown(skill.cooldown)`
    (optional: kick the wedge to full immediately; `cooldown_changed` will follow
    next frame).
  - `cooldown_changed(i, remaining, total)` → `slots[i].set_cooldown(remaining, total)`.
  - `skill_failed(i, reason)` → `slots[i].play_fail()`.
  - `slot_changed(i, skill)` → `slots[i].set_skill(skill)`.

Keep a `var _slots: Array[SkillSlot]` for index→view lookup.

### 5.2 `skill_slot.tscn` / `skill_slot.gd` (`class_name SkillSlot`)

Suggested scene tree (a `Control`/`PanelContainer` root sized ~64×64):

```
SkillSlot (Control)            # frame; dashed/dim style when empty
├── Icon (TextureRect)         # skill.icon, or hidden when using letter fallback
├── Letter (Label)             # first-letter fallback, centered; hidden when Icon shown
├── CooldownWedge (Control)    # custom _draw radial overlay (see 6.1)
├── Seconds (Label)            # remaining seconds, centered; hidden when ready
└── Keybind (Label)            # "1".."4" corner (see 6.2)
```

Public API (visuals kept thin; decision logic in the pure statics of §6):

- `var index: int`
- `func set_skill(skill: Skill) -> void` — filled vs empty:
  - empty (`skill == null`): dim/dashed frame, hide Icon+Letter+Seconds+wedge,
    keep Keybind visible.
  - filled: if `skill.icon` show Icon; else show `Letter` = first char of
    `skill.display_name` on a colored tile. Clear cooldown visuals.
- `func set_cooldown(remaining: float, total: float) -> void`:
  - fraction = `total > 0.0 ? remaining / total : 0.0`; drive the wedge.
  - `Seconds.text = SkillSlot.format_seconds(remaining)`; hide when `remaining <= 0`.
  - if this call transitions from cooling (`_was_cooling`) to ready
    (`remaining <= 0`), call `play_ready()`.
- `func begin_cooldown(total: float) -> void` — optional immediate full wedge on
  cast; safe to no-op and let `set_cooldown` drive it.
- `func play_ready() -> void` — the flash/pulse (§6.3).
- `func play_fail() -> void` — the shake + red tint (§6.4).

---

## 6. Presentation details

### 6.1 Radial cooldown wedge — self-drawn, no art asset

Put this on the `CooldownWedge` `Control`. It draws a dark pie wedge covering the
remaining fraction, sweeping clockwise from the top — the icon is revealed as the
wedge shrinks.

```gdscript
extends Control
var _fraction: float = 0.0   # 0 = ready (nothing drawn), 1 = full cover

func set_fraction(f: float) -> void:
	_fraction = clampf(f, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	if _fraction <= 0.0:
		return
	var center := size / 2.0
	var radius := maxf(size.x, size.y)   # overshoot to cover corners
	var steps := 48
	var start := -PI / 2.0                # top
	var end := start + TAU * _fraction    # clockwise
	var pts := PackedVector2Array([center])
	for i in steps + 1:
		var a := start + (end - start) * (float(i) / steps)
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
```

(Alternative if you prefer a stock node: a `TextureProgressBar` with
`fill_mode = FILL_CLOCKWISE`, a plain white `texture_progress`, dark
`tint_progress`, `value = 100 * remaining / total`. The self-drawn version needs
no texture asset — prefer it.)

### 6.2 Keybind label — read from the InputMap, don't hardcode

Future-proof against rebinds. Pure static, unit-testable:

```gdscript
static func keybind_label(index: int) -> String:
	var action := StringName("skill_%d" % (index + 1))
	if InputMap.has_action(action):
		for e in InputMap.action_get_events(action):
			if e is InputEventKey:
				return (e as InputEventKey).as_text_physical_keycode()
	return str(index + 1)
```

### 6.3 Seconds format — integer, Diablo-style

```gdscript
static func format_seconds(remaining: float) -> String:
	return "" if remaining <= 0.0 else str(ceili(remaining))
```

### 6.4 Ready flash

One-shot on the ready transition — scale pop + brief bright modulate:

```gdscript
func play_ready() -> void:
	var t := create_tween()
	t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
	t.tween_property(self, "scale", Vector2.ONE, 0.12)
	# optional parallel: flash self.modulate to a bright tint and back
```

### 6.5 Fail shake / red flash

One-shot on `skill_failed`, short horizontal shake + red tint that decays:

```gdscript
func play_fail() -> void:
	modulate = Color(1, 0.5, 0.5)
	var t := create_tween()
	for dx in [8.0, -6.0, 4.0, -2.0, 0.0]:
		t.tween_property(self, "position:x", _base_x + dx, 0.04)
	t.parallel().tween_property(self, "modulate", Color.WHITE, 0.2)
```

(Cache `_base_x` in `_ready`; container layout may reset it — if the HBox fights
the tween, shake an inner child's `position` instead of the slot root.)

---

## 7. Testing (GUT, headless)

Keep decision logic in the pure statics (`keybind_label`, `format_seconds`, the
fraction math) so it's assertable without rendering.

### 7.1 `test/core/test_ability_component.gd` (extend existing)

- `equip(skill, 2)` emits `slot_changed(2, skill)`.
- `unequip(0)` emits `slot_changed(0, null)`.
  (Use GUT's `watch_signals` / `assert_signal_emitted_with_parameters`.)

### 7.2 `test/ui/test_skill_slot.gd` (new — pure logic)

- `format_seconds`: `0.0 → ""`, `2.9 → "3"`, `0.01 → "1"`.
- `keybind_label(0)` returns the key mapped to `skill_1` (assert against
  `InputMap`), and falls back to `"1"` for an unmapped index.
- fraction math: `remaining/total` clamps and `total == 0` → `0`.

### 7.3 `test/ui/test_skill_bar.gd` (new — binding model)

Feed a **fake** ability component (a `Node` with `skill_activated`,
`cooldown_changed`, `skill_failed`, `slot_changed` signals, a `slots` array, and
`const SLOT_COUNT := 4`) into `SkillBar.bind()`; use `add_child_autofree` so the
HUD is in-tree. Assert on the slots' observable state (a `state()` getter or the
node visibility/text):

- after `bind` with slots [Sprint, SuperJump, null, null] → slots 0,1 filled
  (correct letter/name), slots 2,3 empty.
- emit `cooldown_changed(0, 5, 10)` → slot 0 fraction ≈ 0.5, seconds "5".
- emit `cooldown_changed(0, 0, 10)` → slot 0 reads ready (seconds hidden).
- emit `slot_changed(2, someSkill)` → slot 2 becomes filled.
- emit `skill_failed(1, &"on_cooldown")` → slot 1 `play_fail` ran (a boolean flag
  toggled is enough — don't assert on tween internals).

Run via the `godot-gut-tests` skill (headless Godot + GUT).

---

## 8. Wiring checklist (scene edits)

1. `skills/core/ability_component.gd`: add `slot_changed` + emit in
   `equip`/`unequip` (§3).
2. Create `ui/skill_bar/` scenes + scripts (§5–§6).
3. `main.tscn`: attach new `main.gd` to `Main`; instance `skill_bar.tscn` as a
   child named `SkillBarHUD`.
4. `main.gd`: `hud.bind(player.abilities)` in `_ready` (§4).
5. Tests (§7). Run headless; all green.
6. Manual verify: run `main.tscn` — 2 filled slots (S, J letters) + 2 dashed
   empty slots, all showing keybinds. Press 2 (SuperJump, 4s cd): wedge sweeps,
   seconds count 4→1, then flash to ready. Press 2 mid-cooldown: shake/red. Press
   3 (empty): shake.

---

## 9. Assumed defaults (flag if you disagree, don't silently change)

- Slot size ~64px; exact styling/theme is implementer's discretion (placeholder).
- Wedge alpha 0.6, flash 0.2s, shake ~0.2s — all tunable; feel free to taste.
- Empty-slot "dashed" look can be a dim `StyleBoxFlat` border; no art needed.
- Letter-fallback tile color: pick a neutral; no per-skill color mapping yet.
