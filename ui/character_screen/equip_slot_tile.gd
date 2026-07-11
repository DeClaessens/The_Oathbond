class_name EquipSlotTile
extends Panel

## One of the doll's 11 equip slots (BLUEPRINT.md). Drop target for an
## inventory item ("kind":"item") when `Equipment.validate` says it's legal
## for this slot, and a drag source when filled ("kind":"equipped") so
## dropping on another compatible slot re-equips (rings swap between ring
## slots). All mutation goes through EquipmentComponent -- this tile never
## touches stats or inventory directly.

const HIGHLIGHT_COLOR := Color(0.4, 0.85, 0.5)
const EMPTY_ALPHA := 0.6

var equip_slot: ItemTypes.EquipSlot = ItemTypes.EquipSlot.WEAPON
var label_text: String = ""

var _screen: Node  # CharacterScreen; duck-typed to dodge a cyclic preload
var _equipment: EquipmentComponent
var _stats: StatsComponent
var _item: ItemInstance

@onready var _label: Label = $Label
@onready var _icon: TextureRect = $Icon
@onready var _name_label: Label = $NameLabel

func _ready() -> void:
    custom_minimum_size = Vector2(50, 50)
    mouse_filter = Control.MOUSE_FILTER_STOP
    mouse_entered.connect(_on_mouse_entered)
    mouse_exited.connect(_on_mouse_exited)
    gui_input.connect(_on_gui_input)
    _label.text = label_text
    refresh()

func setup(slot: ItemTypes.EquipSlot, text: String) -> void:
    equip_slot = slot
    label_text = text
    if _label != null:
        _label.text = text

func bind(screen: Node, equipment: EquipmentComponent, stats: StatsComponent) -> void:
    _screen = screen
    _equipment = equipment
    _stats = stats
    refresh()

func refresh() -> void:
    if _label == null:
        return
    _item = _equipment.equipped(equip_slot) if _equipment != null else null
    var box := StyleBoxFlat.new()
    box.set_corner_radius_all(6)
    box.set_border_width_all(1)
    if _item != null:
        var def := _item.definition()
        box.bg_color = Color(0.114, 0.129, 0.149)  # #1d2126
        box.border_color = ItemCard.RARITY_COLORS.get(_item.rarity, Color(0.227, 0.259, 0.298))
        modulate = Color.WHITE
        _label.hide()
        _icon.show()
        _name_label.show()
        _icon.texture = def.icon if def != null else null
        _name_label.text = def.display_name if def != null else String(_item.definition_id)
    else:
        box.bg_color = Color(0.149, 0.173, 0.2)  # #262c33
        box.border_color = Color(0.227, 0.259, 0.298)  # #3a424c
        modulate = Color(1, 1, 1, EMPTY_ALPHA)
        _label.show()
        _icon.hide()
        _name_label.hide()
    add_theme_stylebox_override("panel", box)

func _on_gui_input(event: InputEvent) -> void:
    if _item != null and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        _equipment.unequip(equip_slot)

func _on_mouse_entered() -> void:
    if _item != null and _screen != null:
        _screen.show_tooltip(_item, null, get_global_rect())

func _on_mouse_exited() -> void:
    if _screen != null:
        _screen.hide_tooltip()

func _get_drag_data(_pos: Vector2) -> Variant:
    if _item == null:
        return null
    if _screen != null:
        _screen.hide_tooltip()
    set_drag_preview(_make_preview(_item))
    return {"kind": "equipped", "slot": equip_slot}

func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
    var ok := false
    if data is Dictionary and _stats != null:
        if data.get("kind") == "item":
            ok = Equipment.validate(data.get("item"), equip_slot, _stats).ok
        elif data.get("kind") == "equipped":
            var other_slot: ItemTypes.EquipSlot = data.get("slot")
            var other_item := _equipment.equipped(other_slot)
            ok = other_slot != equip_slot and other_item != null and Equipment.validate(other_item, equip_slot, _stats).ok
    _set_highlight(ok)
    return ok

func _drop_data(_pos: Vector2, data: Variant) -> void:
    _set_highlight(false)
    if data.get("kind") == "item":
        var result := _equipment.equip(data.get("item"), equip_slot)
        if not result.ok and _screen != null:
            _screen.set_status(_reason_text(result.reason))
    elif data.get("kind") == "equipped":
        var other_slot: ItemTypes.EquipSlot = data.get("slot")
        var other_item := _equipment.equipped(other_slot)
        _equipment.equip(other_item, equip_slot)

func _reason_text(reason: StringName) -> String:
    match reason:
        &"wrong_slot":
            return "Wrong slot"
        &"requirements_not_met":
            return "Requirements not met"
    return String(reason)

func _notification(what: int) -> void:
    if what == NOTIFICATION_DRAG_END:
        _set_highlight(false)

func _set_highlight(on: bool) -> void:
    if on:
        var box: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
        box.border_color = HIGHLIGHT_COLOR
        box.set_border_width_all(2)
        add_theme_stylebox_override("panel", box)
    else:
        refresh()

func _make_preview(item: ItemInstance) -> Control:
    var def := item.definition()
    var preview := Label.new()
    preview.text = def.display_name if def != null else String(item.definition_id)
    preview.modulate = Color(1.0, 1.0, 1.0, 0.85)
    preview.custom_minimum_size = Vector2(48, 48)
    preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    return preview
