class_name EquipSlotView
extends Control

## One of the Skills Window's four Ability Slot views: embeds the existing
## SkillSlot renderer (icon/letter tile, keybind label) so the window and the
## Skill Bar HUD stay visually identical, and adds the interactive layer the
## HUD doesn't need -- drag source/target, hover-visible unequip button, and
## drop-target highlighting. All mutation goes through the existing
## AbilityComponent.equip/unequip API (ADR-0002): this view adds no new
## component methods.

const HIGHLIGHT_BORDER := Color(0.4, 0.85, 0.5)

var index: int = 0

var _abilities: AbilityComponent
var _player: Player
var _skill: Skill

@onready var _slot: SkillSlot = $SkillSlot
@onready var _remove_button: Button = $RemoveButton

func _ready() -> void:
    custom_minimum_size = Vector2(64, 64)
    mouse_filter = Control.MOUSE_FILTER_STOP
    _slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _remove_button.hide()
    _remove_button.pressed.connect(_on_remove_pressed)
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)

func bind(abilities: AbilityComponent, player: Player) -> void:
    _abilities = abilities
    _player = player
    _slot.index = index
    refresh()

func refresh() -> void:
    if _abilities == null:
        return
    var slot: AbilitySlot = _abilities.slots[index]
    _skill = slot.skill if slot != null else null
    _slot.set_skill(_skill)
    tooltip_text = _tooltip_text(_skill)
    _remove_button.hide()

func _tooltip_text(skill: Skill) -> String:
    if skill == null:
        return ""
    var lines: Array[String] = [skill.display_name, skill.description, "Cooldown: %ss" % skill.cooldown]
    if skill.mana_cost > 0.0:
        lines.append("Mana: %s" % skill.mana_cost)
    return "\n".join(lines)

func _on_mouse_entered() -> void:
    if _skill != null:
        _remove_button.show()

func _on_mouse_exited() -> void:
    _remove_button.hide()

func _on_remove_pressed() -> void:
    _abilities.unequip(index)

func _get_drag_data(_pos: Vector2) -> Variant:
    if _skill == null:
        return null
    var preview := _make_preview(_skill)
    set_drag_preview(preview)
    return {"kind": "slot", "index": index}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
    var ok: bool = data is Dictionary and (data.get("kind") == "library" or data.get("kind") == "slot")
    _set_highlight(ok)
    return ok

func _drop_data(_pos: Vector2, data: Variant) -> void:
    _set_highlight(false)
    match data.kind:
        "library":
            _player.grant_and_equip(data.skill, index)
        "slot":
            _swap_with(data.index)

func _swap_with(other_index: int) -> void:
    if other_index == index:
        return
    var this_slot: AbilitySlot = _abilities.slots[index]
    var other_slot: AbilitySlot = _abilities.slots[other_index]
    var this_skill: Skill = this_slot.skill if this_slot != null else null
    var other_skill: Skill = other_slot.skill if other_slot != null else null
    if other_skill != null:
        _abilities.equip(other_skill, index)
    else:
        _abilities.unequip(index)
    if this_skill != null:
        _abilities.equip(this_skill, other_index)
    else:
        _abilities.unequip(other_index)

func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        _set_highlight(false)

func _set_highlight(on: bool) -> void:
    modulate = HIGHLIGHT_BORDER if on else Color.WHITE

func _make_preview(skill: Skill) -> Control:
    var preview := Label.new()
    preview.text = SkillSlot.first_letter(skill.display_name)
    preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
    preview.custom_minimum_size = Vector2(48, 48)
    preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return preview
