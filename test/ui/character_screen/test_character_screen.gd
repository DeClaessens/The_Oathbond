extends GutTest

const CharacterScreenScene := preload("res://ui/character_screen/character_screen.tscn")

func test_equipment_change_hides_a_visible_tooltip():
    var screen: CharacterScreen = CharacterScreenScene.instantiate()
    add_child_autofree(screen)
    var tooltip: PanelContainer = screen.get_node(^"Tooltip")
    tooltip.show()

    screen._on_equipment_changed(ItemTypes.EquipSlot.BODY)

    assert_false(tooltip.visible)
