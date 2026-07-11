class_name CharacterScreen
extends CanvasLayer

## The styled inventory + equipment + inspect screen (BLUEPRINT.md, variant D)
## that replaces the M2.3 functional InventoryPanel and supersedes M2.4
## decision 8's plain panel. Toggled by `toggle_inventory` (I), copying the
## SkillsWindow window/pause/backdrop idiom -- open pauses the tree, close
## resumes, no panel-stack coordination with other windows (accepted
## limitation). All mutation goes through InventoryComponent/EquipmentComponent
## -- this screen never applies a mod or touches `_equipped` itself.

const EquipSlotTileScene := preload("res://ui/character_screen/equip_slot_tile.tscn")
const InventorySlotTileScene := preload("res://ui/character_screen/inventory_slot_tile.tscn")
const ItemCardScene := preload("res://ui/character_screen/item_card.tscn")

## (EquipSlot, label text, doll-local top-left position) -- BLUEPRINT.md's map.
const SLOT_LAYOUT := [
    [ItemTypes.EquipSlot.HELM, "Helm", Vector2(55, 0)],
    [ItemTypes.EquipSlot.AMULET, "Amulet", Vector2(55, 54)],
    [ItemTypes.EquipSlot.OFF_HAND, "Off-hand", Vector2(0, 108)],
    [ItemTypes.EquipSlot.BODY, "Body", Vector2(55, 108)],
    [ItemTypes.EquipSlot.WEAPON, "Weapon", Vector2(110, 108)],
    [ItemTypes.EquipSlot.GLOVES, "Gloves", Vector2(0, 162)],
    [ItemTypes.EquipSlot.BELT, "Belt", Vector2(55, 162)],
    [ItemTypes.EquipSlot.BOOTS, "Boots", Vector2(110, 162)],
    [ItemTypes.EquipSlot.RING_1, "Ring 1", Vector2(10, 216)],
    [ItemTypes.EquipSlot.RELIC, "Relic", Vector2(65, 216)],
    [ItemTypes.EquipSlot.RING_2, "Ring 2", Vector2(110, 216)],
]

var _inventory: InventoryComponent
var _equipment: EquipmentComponent
var _stats: StatsComponent
var _player: Player

var _slot_tiles: Array = []
var _inventory_tiles: Array = []
var _pinned_item: ItemInstance

@onready var _backdrop: Panel = $Backdrop
@onready var _window: PanelContainer = $Backdrop/Center/Window
@onready var _doll: Control = %Doll
@onready var _status_line: Label = %StatusLine
@onready var _might_value: Label = %MightValue
@onready var _grace_value: Label = %GraceValue
@onready var _wit_value: Label = %WitValue
@onready var _health_value: Label = %HealthValue
@onready var _mana_value: Label = %ManaValue
@onready var _grid: GridContainer = %Grid
@onready var _inspect_empty: Label = %InspectEmpty
@onready var _pinned_card_root: VBoxContainer = %PinnedCard
@onready var _pinned_card: ItemCard = %PinnedItemCard
@onready var _pinned_close: Button = %PinnedClose
@onready var _tooltip: PanelContainer = %Tooltip
@onready var _tooltip_card: ItemCard = %TooltipItemCard

func _ready() -> void:
    process_mode = Node.PROCESS_MODE_ALWAYS
    visible = false
    _backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
    var dim := StyleBoxFlat.new()
    dim.bg_color = Color(0, 0, 0, 0.5)
    _backdrop.add_theme_stylebox_override("panel", dim)

    var window_box := StyleBoxFlat.new()
    window_box.bg_color = Color(0.114, 0.129, 0.149)
    window_box.border_color = Color(0.227, 0.259, 0.298)
    window_box.set_border_width_all(1)
    window_box.set_corner_radius_all(6)
    _window.add_theme_stylebox_override("panel", window_box)

    for entry in SLOT_LAYOUT:
        var tile: EquipSlotTile = EquipSlotTileScene.instantiate()
        tile.setup(entry[0], entry[1])
        tile.position = entry[2]
        _doll.add_child(tile)
        _slot_tiles.append(tile)

    _pinned_close.pressed.connect(_on_pinned_close_pressed)
    _pinned_card_root.hide()
    _inspect_empty.show()
    _tooltip.hide()
    _tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _tooltip.top_level = true
    _status_line.text = ""

func bind(inventory: InventoryComponent, equipment: EquipmentComponent, stats: StatsComponent, player: Player) -> void:
    if _inventory != null and _inventory.inventory_changed.is_connected(_rebuild_grid):
        _inventory.inventory_changed.disconnect(_rebuild_grid)
    if _equipment != null and _equipment.equipment_changed.is_connected(_on_equipment_changed):
        _equipment.equipment_changed.disconnect(_on_equipment_changed)
    if _stats != null and _stats.stat_changed.is_connected(_on_stat_changed):
        _stats.stat_changed.disconnect(_on_stat_changed)

    _inventory = inventory
    _equipment = equipment
    _stats = stats
    _player = player

    _inventory.inventory_changed.connect(_rebuild_grid)
    _equipment.equipment_changed.connect(_on_equipment_changed)
    _stats.stat_changed.connect(_on_stat_changed)

    for tile in _slot_tiles:
        tile.bind(self, _equipment, _stats)

    _rebuild_grid()
    _refresh_stats_footer()

func is_open() -> bool:
    return visible

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"toggle_inventory"):
        _set_open(not visible)
        get_viewport().set_input_as_handled()
    elif visible and event.is_action_pressed(&"ui_cancel"):
        _set_open(false)
        get_viewport().set_input_as_handled()

func set_status(text: String) -> void:
    _status_line.text = text

func show_tooltip(item: ItemInstance, compare_to: ItemInstance, target_rect: Rect2) -> void:
    if get_viewport().gui_is_dragging():
        return
    _tooltip_card.bind_stats(_stats)
    _tooltip_card.set_item(item, compare_to)
    _tooltip.show()
    _position_tooltip(target_rect)

func hide_tooltip() -> void:
    _tooltip.hide()

func _set_open(open: bool) -> void:
    visible = open
    get_tree().paused = open
    if open:
        _status_line.text = ""

func _rebuild_grid() -> void:
    if _grid == null or _inventory == null:
        return
    for child in _grid.get_children():
        child.queue_free()
    _inventory_tiles.clear()

    var items := _inventory.items()
    for item in items:
        _inventory_tiles.append(_make_inventory_tile(item))
    for i in range(items.size(), InventoryComponent.CAPACITY):
        _inventory_tiles.append(_make_inventory_tile(null))

    _refresh_pinned()

func _make_inventory_tile(item: ItemInstance) -> InventorySlotTile:
    var tile: InventorySlotTile = InventorySlotTileScene.instantiate()
    _grid.add_child(tile)
    tile.bind(self, _equipment)
    tile.set_item(item)
    tile.inspect_requested.connect(_on_inspect_requested)
    return tile

func _on_equipment_changed(_slot: ItemTypes.EquipSlot) -> void:
    for tile in _slot_tiles:
        tile.refresh()
    _refresh_pinned()

func _on_stat_changed(_stat: StringName, _value: float) -> void:
    _refresh_stats_footer()

func _refresh_stats_footer() -> void:
    if _stats == null:
        return
    _might_value.text = _format_stat(_stats.get_stat(StatKeys.MIGHT))
    _grace_value.text = _format_stat(_stats.get_stat(StatKeys.GRACE))
    _wit_value.text = _format_stat(_stats.get_stat(StatKeys.WIT))
    _health_value.text = _format_stat(_stats.get_stat(StatKeys.MAX_HEALTH))
    _mana_value.text = _format_stat(_stats.get_stat(StatKeys.MAX_MANA))

func _format_stat(value: float) -> String:
    if is_equal_approx(value, roundf(value)):
        return str(int(round(value)))
    return "%.1f" % value

func _on_inspect_requested(item: ItemInstance) -> void:
    _pinned_item = item
    _refresh_pinned()

func _on_pinned_close_pressed() -> void:
    _pinned_item = null
    _refresh_pinned()

## Re-resolves the pinned card against current state (BLUEPRINT.md: a pinned
## item that gets equipped/removed re-renders or unpins) -- called on every
## inventory_changed and equipment_changed.
func _refresh_pinned() -> void:
    if _pinned_item != null and _inventory != null and not _inventory.items().has(_pinned_item):
        _pinned_item = null

    if _pinned_item == null:
        _pinned_card_root.hide()
        _inspect_empty.show()
        return

    _inspect_empty.hide()
    _pinned_card_root.show()
    var target = EquipmentComponent.default_slot_for(_pinned_item, _equipment)
    var equipped_there: ItemInstance = _equipment.equipped(target) if target != null and _equipment != null else null
    _pinned_card.bind_stats(_stats)
    _pinned_card.set_item(_pinned_item, equipped_there)

func _position_tooltip(target_rect: Rect2) -> void:
    var viewport_size := get_viewport().get_visible_rect().size
    var tooltip_size := _tooltip.size
    var pos := Vector2(target_rect.position.x + target_rect.size.x + 12.0, target_rect.position.y)
    if pos.x + tooltip_size.x > viewport_size.x:
        pos.x = target_rect.position.x - tooltip_size.x - 12.0
    pos.y = clampf(pos.y, 0.0, maxf(0.0, viewport_size.y - tooltip_size.y))
    _tooltip.position = pos
