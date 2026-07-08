class_name InventoryPanel
extends CanvasLayer

## Functional inventory list toggled by the `toggle_inventory` action (bound to
## I). Shows each held item's display name, rarity (name + color), and its
## ROLLED affix values -- not the definition's pool ranges (decision 10: the UI
## proves instances carry their own numbers). Mirrors the skill-bar HUD wiring:
## read-only, bound to InventoryComponent.inventory_changed.

const RARITY_NAMES := {
    ItemTypes.Rarity.COMMON: "Common",
    ItemTypes.Rarity.QUALITY: "Quality",
    ItemTypes.Rarity.MASTERWORK: "Masterwork",
    ItemTypes.Rarity.HEIRLOOM: "Heirloom",
}

const RARITY_COLORS := {
    ItemTypes.Rarity.COMMON: Color(0.75, 0.75, 0.75),
    ItemTypes.Rarity.QUALITY: Color(0.35, 0.8, 0.4),
    ItemTypes.Rarity.MASTERWORK: Color(0.95, 0.78, 0.3),
    ItemTypes.Rarity.HEIRLOOM: Color(0.95, 0.55, 0.25),
}

var _inventory: InventoryComponent

@onready var _list: VBoxContainer = $Panel/Margin/Scroll/List

func _ready() -> void:
    visible = false

func bind(inventory: InventoryComponent) -> void:
    if _inventory != null and _inventory.inventory_changed.is_connected(_rebuild):
        _inventory.inventory_changed.disconnect(_rebuild)
    _inventory = inventory
    if _inventory != null:
        _inventory.inventory_changed.connect(_rebuild)
    _rebuild()

func is_open() -> bool:
    return visible

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"toggle_inventory"):
        visible = not visible
        if visible:
            _rebuild()

func _rebuild() -> void:
    if _list == null:
        return
    for child in _list.get_children():
        child.queue_free()
    if _inventory == null:
        return
    for item in _inventory.items():
        _list.add_child(_make_row(item))

func _make_row(item: ItemInstance) -> Control:
    var row := VBoxContainer.new()
    var header := Label.new()
    var def := item.definition()
    var name_text: String = def.display_name if def != null else String(item.definition_id)
    header.text = "%s  [%s]" % [name_text, RARITY_NAMES.get(item.rarity, "?")]
    header.add_theme_color_override("font_color", RARITY_COLORS.get(item.rarity, Color.WHITE))
    row.add_child(header)
    for affix in item.rolled_affixes:
        var line := Label.new()
        line.text = "    %s" % _affix_text(affix)
        row.add_child(line)
    return row

## Renders a rolled affix's own value (never the pool range).
func _affix_text(affix: ItemAffix) -> String:
    match affix.op:
        StatModifier.Op.FLAT:
            return "+%.1f %s" % [affix.value, affix.stat]
        StatModifier.Op.ADD_PCT, StatModifier.Op.MULT_PCT:
            return "+%.0f%% %s" % [affix.value * 100.0, affix.stat]
    return "%s %s" % [affix.value, affix.stat]
