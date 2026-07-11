class_name InventorySlotTile
extends Panel

## One tile in the 6-column inventory grid (BLUEPRINT.md). Read-only about
## its own item -- hover shows the Tooltip (with delta arrows against
## whatever's equipped in this item's target slot), click pins it in the
## InspectPanel, drag starts an equip attempt on a compatible EquipSlotTile.
## No stack badge: items don't stack (each ItemInstance is unique).

signal inspect_requested(item: ItemInstance)

const EMPTY_ALPHA := 0.4

var _screen: Node  # CharacterScreen
var _equipment: EquipmentComponent
var _item: ItemInstance

@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $NameLabel

func _ready() -> void:
    custom_minimum_size = Vector2(64, 64)
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    gui_input.connect(_on_gui_input)
    _refresh_visual()

func bind(screen: Node, equipment: EquipmentComponent) -> void:
    _screen = screen
    _equipment = equipment

func set_item(item: ItemInstance) -> void:
    _item = item
    if is_inside_tree():
        _refresh_visual()

func _refresh_visual() -> void:
    var box := StyleBoxFlat.new()
    box.set_corner_radius_all(6)
    box.set_border_width_all(1)
    if _item != null:
        var def := _item.definition()
        box.bg_color = Color(0.149, 0.173, 0.2)  # #262c33
        box.border_color = ItemCard.RARITY_COLORS.get(_item.rarity, Color(0.227, 0.259, 0.298))
        modulate = Color.WHITE
        _icon.show()
        _name_label.show()
        _icon.texture = def.icon if def != null else null
        _name_label.text = def.display_name if def != null else String(_item.definition_id)
    else:
        box.bg_color = Color(0.114, 0.129, 0.149)  # #1d2126
        box.border_color = Color(0.227, 0.259, 0.298)  # #3a424c
        modulate = Color(1, 1, 1, EMPTY_ALPHA)
        _icon.hide()
        _name_label.hide()
    add_theme_stylebox_override("panel", box)

func _on_mouse_entered() -> void:
    if _item != null and _screen != null:
        var target = EquipmentComponent.default_slot_for(_item, _equipment)
        var equipped_there: ItemInstance = _equipment.equipped(target) if target != null and _equipment != null else null
        _screen.show_tooltip(_item, equipped_there, get_global_rect())

func _on_mouse_exited() -> void:
    if _screen != null:
        _screen.hide_tooltip()

func _on_gui_input(event: InputEvent) -> void:
    if _item != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        inspect_requested.emit(_item)

func _get_drag_data(_pos: Vector2) -> Variant:
    if _item == null:
        return null
    if _screen != null:
        _screen.hide_tooltip()
    set_drag_preview(_make_preview(_item))
    return {"kind": "item", "item": _item}

func _make_preview(item: ItemInstance) -> Control:
    var def := item.definition()
    var preview := Label.new()
    preview.text = def.display_name if def != null else String(item.definition_id)
    preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
    preview.custom_minimum_size = Vector2(56, 56)
    preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return preview
