extends GutTest

const InventoryPanelScene := preload("res://ui/inventory/inventory_panel.tscn")

func _build() -> Array:
    var inv := InventoryComponent.new()
    add_child_autofree(inv)
    var panel: InventoryPanel = InventoryPanelScene.instantiate()
    add_child_autofree(panel)
    panel.bind(inv)
    return [panel, inv]

func _make_item() -> ItemInstance:
    var inst := ItemInstance.new()
    inst.definition_id = &"rusted_sickle"
    inst.rarity = ItemTypes.Rarity.MASTERWORK
    inst.rolled_affixes = [ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 6.5)]
    return inst

func _all_text(node: Node) -> String:
    var text := ""
    if node is Label:
        text += (node as Label).text + "\n"
    for child in node.get_children():
        text += _all_text(child)
    return text

func test_panel_starts_hidden():
    var built := _build()
    assert_false((built[0] as InventoryPanel).is_open())

func test_panel_lists_the_items_rolled_value_name_and_rarity():
    var built := _build()
    var panel: InventoryPanel = built[0]
    var inv: InventoryComponent = built[1]
    inv.add(_make_item())

    var text := _all_text(panel)
    assert_string_contains(text, "Rusted Sickle", "shows the definition display name")
    assert_string_contains(text, "Masterwork", "shows the rarity name")
    assert_string_contains(text, "6.5", "shows the ROLLED affix value, not the pool range")
    assert_string_contains(text, "dmg_ember", "shows the affix stat")

func test_rebuild_reflects_inventory_changes():
    var built := _build()
    var panel: InventoryPanel = built[0]
    var inv: InventoryComponent = built[1]
    assert_false(_all_text(panel).contains("Rusted Sickle"))

    inv.add(_make_item())
    assert_string_contains(_all_text(panel), "Rusted Sickle", "the panel reacts to inventory_changed")
