class_name SkillSlot
extends Control

## One read-only view of an Ability Slot: shows the equipped Skill (icon or
## first-letter tile), the live radial cooldown wedge with a seconds numeral, and
## plays a ready flash / fail shake. All decision logic lives in the pure statics
## below so it is testable without rendering.

const FILLED_BG := Color(0.12, 0.13, 0.17, 0.85)
const FILLED_BORDER := Color(0.55, 0.6, 0.72)
const EMPTY_BG := Color(0.08, 0.09, 0.11, 0.35)
const EMPTY_BORDER := Color(0.35, 0.37, 0.44, 0.55)
const LETTER_TILE := Color(0.2, 0.28, 0.44)
const WEDGE_COLOR := Color(0, 0, 0, 0.6)

var index: int = 0

var _filled: bool = false
var _fraction: float = 0.0
var _was_cooling: bool = false
var _base_modulate: Color = Color.WHITE
var _ready_plays: int = 0
var _fail_plays: int = 0

@onready var _content: Control = $Content
@onready var _frame: Panel = $Content/Frame
@onready var _icon: TextureRect = $Content/Icon
@onready var _letter: Label = $Content/Letter
@onready var _wedge: Control = $Content/CooldownWedge
@onready var _seconds: Label = $Content/Seconds
@onready var _keybind: Label = $Content/Keybind


# --- Pure statics (no tree access — unit-testable) -----------------------------

static func format_seconds(remaining: float) -> String:
    return "" if remaining <= 0.0 else str(ceili(remaining))

static func cooldown_fraction(remaining: float, total: float) -> float:
    if total <= 0.0:
        return 0.0
    return clampf(remaining / total, 0.0, 1.0)

static func keybind_label(slot_index: int) -> String:
    var action := StringName("skill_%d" % (slot_index + 1))
    if InputMap.has_action(action):
        for e in InputMap.action_get_events(action):
            if e is InputEventKey:
                return (e as InputEventKey).as_text_physical_keycode()
    return str(slot_index + 1)

static func first_letter(display_name: String) -> String:
    return display_name.substr(0, 1).to_upper() if display_name != "" else "?"


# --- Lifecycle -----------------------------------------------------------------

func _ready() -> void:
    custom_minimum_size = Vector2(64, 64)
    for c: Control in [_content, _frame, _icon, _letter, _wedge, _seconds]:
        c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
        c.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _keybind.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    _keybind.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _seconds.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _seconds.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    _keybind.text = SkillSlot.keybind_label(index)
    _wedge.draw.connect(_on_wedge_draw)
    set_skill(null)


# --- Public API (thin visuals) -------------------------------------------------

func set_skill(skill: Skill) -> void:
    _clear_cooldown()
    _filled = skill != null
    if not _filled:
        _apply_frame(EMPTY_BG, EMPTY_BORDER)
        _icon.hide()
        _letter.hide()
        _seconds.hide()
        _wedge.hide()
        _base_modulate = Color(1, 1, 1, 0.55)
    else:
        _apply_frame(FILLED_BG, FILLED_BORDER)
        _base_modulate = Color.WHITE
        if skill.icon != null:
            _icon.texture = skill.icon
            _icon.show()
            _letter.hide()
            _letter.remove_theme_stylebox_override("normal")
        else:
            _icon.hide()
            _letter.text = SkillSlot.first_letter(skill.display_name)
            _letter.add_theme_stylebox_override("normal", _make_box(LETTER_TILE, LETTER_TILE))
            _letter.show()
    _content.modulate = _base_modulate

func set_cooldown(remaining: float, total: float) -> void:
    _fraction = SkillSlot.cooldown_fraction(remaining, total)
    _wedge.visible = _fraction > 0.0
    _wedge.queue_redraw()
    var text := SkillSlot.format_seconds(remaining)
    _seconds.text = text
    _seconds.visible = text != ""
    var cooling := remaining > 0.0
    if _was_cooling and not cooling:
        play_ready()
    _was_cooling = cooling

## Optional immediate full wedge on cast; set_cooldown drives the rest.
func begin_cooldown(total: float) -> void:
    if total > 0.0:
        set_cooldown(total, total)

func play_ready() -> void:
    _ready_plays += 1
    if not is_inside_tree():
        return
    pivot_offset = size / 2.0
    var t := create_tween()
    t.tween_property(self, "scale", Vector2(1.15, 1.15), 0.08)
    t.tween_property(self, "scale", Vector2.ONE, 0.12)

func play_fail() -> void:
    _fail_plays += 1
    if not is_inside_tree():
        return
    _content.modulate = Color(1, 0.5, 0.5)
    var t := create_tween()
    for dx: float in [8.0, -6.0, 4.0, -2.0, 0.0]:
        t.tween_property(_content, "position:x", dx, 0.04)
    t.parallel().tween_property(_content, "modulate", _base_modulate, 0.2)

## Observable state for tests (no rendering required).
func state() -> Dictionary:
    return {
        "filled": _filled,
        "letter": _letter.text,
        "letter_visible": _letter.visible,
        "icon_visible": _icon.visible,
        "seconds": _seconds.text,
        "seconds_visible": _seconds.visible,
        "fraction": _fraction,
        "ready_plays": _ready_plays,
        "fail_plays": _fail_plays,
    }


# --- Internals -----------------------------------------------------------------

func _clear_cooldown() -> void:
    _fraction = 0.0
    _was_cooling = false
    if _seconds != null:
        _seconds.text = ""
        _seconds.hide()
    if _wedge != null:
        _wedge.hide()
        _wedge.queue_redraw()

func _apply_frame(bg: Color, border: Color) -> void:
    _frame.add_theme_stylebox_override("panel", _make_box(bg, border))

func _make_box(bg: Color, border: Color) -> StyleBoxFlat:
    var box := StyleBoxFlat.new()
    box.bg_color = bg
    box.set_border_width_all(2)
    box.border_color = border
    box.set_corner_radius_all(6)
    return box

func _on_wedge_draw() -> void:
    if _fraction <= 0.0:
        return
    var wsize := _wedge.size
    var center := wsize / 2.0
    var radius := maxf(wsize.x, wsize.y) / 2   # overshoot to cover corners
    var steps := 48
    var start := -PI / 2.0                 # top
    var end := start + TAU * _fraction     # clockwise
    var pts := PackedVector2Array([center])
    for i in steps + 1:
        var a := start + (end - start) * (float(i) / steps)
        pts.append(center + Vector2(cos(a), sin(a)) * radius)
    _wedge.draw_colored_polygon(pts, WEDGE_COLOR)
