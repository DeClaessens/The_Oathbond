class_name SkillsWindow
extends CanvasLayer

## The player-facing loadout screen (`S` to toggle): four Ability Slot views
## across the top, an Available Skills library below, reassigned by drag and
## drop. Distinct from the read-only Skill Bar HUD -- all mutation lives here,
## going through the existing AbilityComponent.equip/unequip API and
## Player.grant_and_equip (never a new component method, ADR-0002).
##
## Opening pauses the tree; closing always resumes it. Known, accepted
## limitation: this doesn't coordinate with any other panel's open state --
## there's no pause-menu/panel-stack system yet (decision 8 of the brief).

const EquipSlotViewScene := preload("res://ui/skills_window/equip_slot_view.tscn")
const LibraryEntryScene := preload("res://ui/skills_window/library_entry.tscn")

var _abilities: AbilityComponent
var _player: Player
var _slot_views: Array[EquipSlotView] = []

@onready var _backdrop: Panel = $Backdrop
@onready var _slot_row: HBoxContainer = $Backdrop/Panel/Margin/VBox/SlotRow
@onready var _library: GridContainer = $Backdrop/Panel/Margin/VBox/Scroll/Library

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    _backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := StyleBoxFlat.new()
    dim.bg_color = Color(0, 0, 0, 0.5)
    _backdrop.add_theme_stylebox_override("panel", dim)
    for i in AbilityComponent.SLOT_COUNT:
        var view: EquipSlotView = EquipSlotViewScene.instantiate()
        view.index = i
        _slot_row.add_child(view)
        _slot_views.append(view)

func bind(abilities: AbilityComponent, player: Player) -> void:
    if _abilities != null and _abilities.slot_changed.is_connected(_on_slot_changed):
        _abilities.slot_changed.disconnect(_on_slot_changed)
    _abilities = abilities
    _player = player
    _abilities.slot_changed.connect(_on_slot_changed)
    for view in _slot_views:
        view.bind(_abilities, _player)
    _build_library()

func is_open() -> bool:
    return visible

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"toggle_skills"):
        _set_open(not visible)
        get_viewport().set_input_as_handled()
    elif visible and event.is_action_pressed(&"ui_cancel"):
        _set_open(false)
        get_viewport().set_input_as_handled()

func _set_open(open: bool) -> void:
    visible = open
    get_tree().paused = open

func _on_slot_changed(_index: int, _skill: Skill) -> void:
    for view in _slot_views:
        view.refresh()

func _build_library() -> void:
    for child in _library.get_children():
        child.queue_free()
    for skill in SkillCatalog.grantable_skills():
        var entry: LibraryEntry = LibraryEntryScene.instantiate()
        _library.add_child(entry)
        entry.set_skill(skill)
