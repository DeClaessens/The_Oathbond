class_name LibraryEntry
extends Control

## One tile in the Skills Window's Available Skills panel: renders a
## grantable Skill (icon, or SkillSlot's first-letter tile fallback) and is a
## drag source for library -> slot equips. Read-only otherwise -- it never
## mutates anything itself.

const LETTER_TILE := Color(0.2, 0.28, 0.44)
const BG := Color(0.12, 0.13, 0.17, 0.85)
const BORDER := Color(0.55, 0.6, 0.72)

var skill: Skill

@onready var _frame: Panel = $Frame
@onready var _icon: TextureRect = $Frame/Icon
@onready var _letter: Label = $Frame/Letter

func _ready() -> void:
    custom_minimum_size = Vector2(64, 64)
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    var box := StyleBoxFlat.new()
    box.bg_color = BG
    box.set_border_width_all(2)
    box.border_color = BORDER
    box.set_corner_radius_all(6)
    _frame.add_theme_stylebox_override("panel", box)
    _icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _letter.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _letter.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func set_skill(s: Skill) -> void:
    skill = s
    tooltip_text = _tooltip_text(s)
    if s.icon != null:
        _icon.texture = s.icon
        _icon.show()
        _letter.hide()
    else:
        _icon.hide()
        _letter.text = SkillSlot.first_letter(s.display_name)
        _letter.add_theme_color_override("font_color", Color.WHITE)
        var box := StyleBoxFlat.new()
        box.bg_color = LETTER_TILE
        box.set_corner_radius_all(6)
        _letter.add_theme_stylebox_override("normal", box)
        _letter.show()

func _tooltip_text(s: Skill) -> String:
    var lines: Array[String] = [s.display_name, s.description, "Cooldown: %ss" % s.cooldown]
    if s.mana_cost > 0.0:
        lines.append("Mana: %s" % s.mana_cost)
    return "\n".join(lines)

func _on_mouse_entered() -> void:
    modulate = Color(1.15, 1.15, 1.15)

func _on_mouse_exited() -> void:
    modulate = Color.WHITE

func _get_drag_data(_pos: Vector2) -> Variant:
    var preview := _make_preview()
    set_drag_preview(preview)
    return {"kind": "library", "skill": skill}

func _make_preview() -> Control:
    var preview := Label.new()
    preview.text = SkillSlot.first_letter(skill.display_name)
    preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
    var box := StyleBoxFlat.new()
    box.bg_color = LETTER_TILE
    box.set_corner_radius_all(6)
    preview.add_theme_stylebox_override("normal", box)
    preview.custom_minimum_size = Vector2(48, 48)
    preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return preview
