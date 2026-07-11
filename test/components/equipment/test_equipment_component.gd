extends GutTest

func _make_character(base_stats := {}) -> Node:
    var entity := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = base_stats
    entity.add_child(stats)
    var inventory := InventoryComponent.new()
    inventory.name = "InventoryComponent"
    entity.add_child(inventory)
    var equipment := EquipmentComponent.new()
    equipment.name = "EquipmentComponent"
    entity.add_child(equipment)
    add_child_autofree(entity)
    return entity

func _item(def_id: StringName, affixes: Array = []) -> ItemInstance:
    var inst := ItemInstance.new()
    inst.definition_id = def_id
    inst.rarity = ItemTypes.Rarity.QUALITY
    inst.rolled_affixes.assign(affixes)
    return inst

# --- Equipment.validate table ---

func test_validate_wrong_slot_refuses():
    var entity := _make_character()
    var stats := StatsComponent.of(entity)
    var sickle := _item(&"rusted_sickle") # ItemSlot.WEAPON

    var result := Equipment.validate(sickle, ItemTypes.EquipSlot.BODY, stats)

    assert_false(result.ok)
    assert_eq(result.reason, &"wrong_slot")

func test_validate_unmet_attribute_requirement_refuses():
    var entity := _make_character({StatKeys.MIGHT: 9.0})
    var stats := StatsComponent.of(entity)
    var helm := _item(&"plate_helm") # requires might 10

    var result := Equipment.validate(helm, ItemTypes.EquipSlot.HELM, stats)

    assert_false(result.ok)
    assert_eq(result.reason, &"requirements_not_met")

func test_validate_met_attribute_requirement_succeeds():
    var entity := _make_character({StatKeys.MIGHT: 10.0})
    var stats := StatsComponent.of(entity)
    var helm := _item(&"plate_helm")

    var result := Equipment.validate(helm, ItemTypes.EquipSlot.HELM, stats)

    assert_true(result.ok)
    assert_eq(result.reason, &"")

func test_validate_ring_item_is_legal_in_either_ring_slot():
    var entity := _make_character()
    var stats := StatsComponent.of(entity)
    var ring := _item(&"iron_ring")

    assert_true(Equipment.validate(ring, ItemTypes.EquipSlot.RING_1, stats).ok)
    assert_true(Equipment.validate(ring, ItemTypes.EquipSlot.RING_2, stats).ok)

# --- EquipmentComponent.equip/unequip ---

func test_equip_refuses_wrong_slot_and_applies_nothing():
    var entity := _make_character()
    var equipment := EquipmentComponent.of(entity)
    var stats := StatsComponent.of(entity)
    var sickle := _item(&"rusted_sickle")

    var result := equipment.equip(sickle, ItemTypes.EquipSlot.BODY)

    assert_false(result.ok)
    assert_eq(result.reason, &"wrong_slot")
    assert_null(equipment.equipped(ItemTypes.EquipSlot.BODY))
    assert_eq(stats.get_stat(&"dmg_physical"), 0.0)

func test_equip_refuses_unmet_requirement_and_applies_nothing():
    var entity := _make_character({StatKeys.MIGHT: 5.0})
    var equipment := EquipmentComponent.of(entity)
    var stats := StatsComponent.of(entity)
    var helm := _item(&"plate_helm")

    var result := equipment.equip(helm, ItemTypes.EquipSlot.HELM)

    assert_false(result.ok)
    assert_eq(result.reason, &"requirements_not_met")
    assert_null(equipment.equipped(ItemTypes.EquipSlot.HELM))

func test_equip_unequip_symmetry_including_derived_stat_restoration():
    var entity := _make_character({StatKeys.MIGHT: 10.0})
    var equipment := EquipmentComponent.of(entity)
    var stats := StatsComponent.of(entity)
    var health_before := stats.get_stat(StatKeys.MAX_HEALTH)
    var ember_before := stats.get_stat(&"dmg_ember")

    var hide := _item(&"worn_hide", [
        ItemAffix.new(StatKeys.MIGHT, StatModifier.Op.FLAT, 5.0),
        ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 8.0),
    ])
    var result := equipment.equip(hide, ItemTypes.EquipSlot.BODY)

    assert_true(result.ok)
    assert_eq(stats.get_stat(StatKeys.MIGHT), 15.0)
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), health_before + 10.0, "the +Might item must also raise derived max_health")
    assert_eq(stats.get_stat(&"dmg_ember"), ember_before + 8.0)

    equipment.unequip(ItemTypes.EquipSlot.BODY)

    assert_eq(stats.get_stat(StatKeys.MIGHT), 10.0)
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), health_before, "unequip must restore the exact pre-equip derived value")
    assert_eq(stats.get_stat(&"dmg_ember"), ember_before)

func test_unequip_returns_the_item_to_inventory():
    var entity := _make_character({StatKeys.MIGHT: 10.0})
    var equipment := EquipmentComponent.of(entity)
    var inventory := InventoryComponent.of(entity)
    var hide := _item(&"worn_hide")
    equipment.equip(hide, ItemTypes.EquipSlot.BODY)

    equipment.unequip(ItemTypes.EquipSlot.BODY)

    assert_eq(inventory.size(), 1)
    assert_eq(inventory.items()[0], hide)
    assert_null(equipment.equipped(ItemTypes.EquipSlot.BODY))

func test_unequip_an_empty_slot_is_a_no_op():
    var entity := _make_character()
    var equipment := EquipmentComponent.of(entity)
    watch_signals(equipment)

    equipment.unequip(ItemTypes.EquipSlot.BODY)

    assert_signal_not_emitted(equipment, "equipment_changed")

func test_equip_into_occupied_slot_swaps_old_item_back_to_inventory():
    var entity := _make_character({StatKeys.MIGHT: 10.0})
    var equipment := EquipmentComponent.of(entity)
    var inventory := InventoryComponent.of(entity)
    var stats := StatsComponent.of(entity)
    var old_hide := _item(&"worn_hide", [ItemAffix.new(&"dmg_physical", StatModifier.Op.FLAT, 3.0)])
    var new_hide := _item(&"worn_hide", [ItemAffix.new(&"dmg_physical", StatModifier.Op.FLAT, 9.0)])
    equipment.equip(old_hide, ItemTypes.EquipSlot.BODY)

    var result := equipment.equip(new_hide, ItemTypes.EquipSlot.BODY)

    assert_true(result.ok)
    assert_eq(equipment.equipped(ItemTypes.EquipSlot.BODY), new_hide)
    assert_eq(inventory.size(), 1, "the swapped-out old item must return to inventory")
    assert_eq(inventory.items()[0], old_hide)
    assert_eq(stats.get_stat(&"dmg_physical"), 9.0, "no mod leak -- only the new item's mods remain")

func test_swap_at_capacity_frees_the_incoming_inventory_slot_before_returning_the_old_item():
    var entity := _make_character({StatKeys.MIGHT: 10.0})
    var equipment := EquipmentComponent.of(entity)
    var inventory := InventoryComponent.of(entity)
    var old_hide := _item(&"worn_hide")
    var new_hide := _item(&"worn_hide")
    equipment.equip(old_hide, ItemTypes.EquipSlot.BODY)
    inventory.add(new_hide)
    for i in range(InventoryComponent.CAPACITY - 1):
        assert_true(inventory.add(_item(&"rusted_sickle")))

    var result := equipment.equip(new_hide, ItemTypes.EquipSlot.BODY)

    assert_true(result.ok)
    assert_eq(equipment.equipped(ItemTypes.EquipSlot.BODY), new_hide)
    assert_eq(inventory.size(), InventoryComponent.CAPACITY)
    assert_true(inventory.items().has(old_hide), "the outgoing item must not be lost at capacity")

func test_unequip_at_capacity_leaves_the_item_equipped():
    var entity := _make_character({StatKeys.MIGHT: 10.0})
    var equipment := EquipmentComponent.of(entity)
    var inventory := InventoryComponent.of(entity)
    var hide := _item(&"worn_hide", [ItemAffix.new(StatKeys.MIGHT, StatModifier.Op.FLAT, 5.0)])
    equipment.equip(hide, ItemTypes.EquipSlot.BODY)
    for i in InventoryComponent.CAPACITY:
        assert_true(inventory.add(_item(&"rusted_sickle")))

    equipment.unequip(ItemTypes.EquipSlot.BODY)

    assert_eq(equipment.equipped(ItemTypes.EquipSlot.BODY), hide)
    assert_eq(StatsComponent.of(entity).get_stat(StatKeys.MIGHT), 15.0)
    assert_eq(inventory.size(), InventoryComponent.CAPACITY)

func test_a_ring_equips_into_ring_1_then_a_second_into_ring_2():
    var entity := _make_character()
    var equipment := EquipmentComponent.of(entity)
    var ring_a := _item(&"iron_ring")
    var ring_b := _item(&"iron_ring")

    var result_a := equipment.equip(ring_a, ItemTypes.EquipSlot.RING_1)
    var result_b := equipment.equip(ring_b, ItemTypes.EquipSlot.RING_2)

    assert_true(result_a.ok)
    assert_true(result_b.ok)
    assert_eq(equipment.equipped(ItemTypes.EquipSlot.RING_1), ring_a)
    assert_eq(equipment.equipped(ItemTypes.EquipSlot.RING_2), ring_b)

func test_dragging_an_equipped_ring_to_the_other_ring_slot_swaps_them():
    var entity := _make_character()
    var equipment := EquipmentComponent.of(entity)
    var ring_a := _item(&"iron_ring")
    var ring_b := _item(&"iron_ring")
    equipment.equip(ring_a, ItemTypes.EquipSlot.RING_1)
    equipment.equip(ring_b, ItemTypes.EquipSlot.RING_2)

    var result := equipment.equip(ring_a, ItemTypes.EquipSlot.RING_2)

    assert_true(result.ok)
    assert_eq(equipment.equipped(ItemTypes.EquipSlot.RING_1), ring_b)
    assert_eq(equipment.equipped(ItemTypes.EquipSlot.RING_2), ring_a)

func test_equipment_changed_emits_with_the_slot():
    var entity := _make_character()
    var equipment := EquipmentComponent.of(entity)
    var hide := _item(&"worn_hide")
    watch_signals(equipment)

    equipment.equip(hide, ItemTypes.EquipSlot.BODY)

    assert_signal_emitted_with_parameters(equipment, "equipment_changed", [ItemTypes.EquipSlot.BODY])

# --- save_state / load_state ---

func test_save_state_shape_is_keyed_by_equip_slot_name():
    var entity := _make_character()
    var equipment := EquipmentComponent.of(entity)
    var hide := _item(&"worn_hide")
    equipment.equip(hide, ItemTypes.EquipSlot.BODY)

    var state := equipment.save_state()

    assert_eq(state.keys(), ["BODY"])
    assert_eq(state["BODY"].def_id, "worn_hide")

func test_load_state_rebuilds_and_reapplies_mods():
    var entity := _make_character({StatKeys.MIGHT: 10.0})
    var equipment := EquipmentComponent.of(entity)
    var stats := StatsComponent.of(entity)

    var displaced := equipment.load_state({
        "BODY": {"def_id": "worn_hide", "rarity": int(ItemTypes.Rarity.QUALITY),
                  "affixes": [{"stat": "max_health", "op": int(StatModifier.Op.FLAT), "value": 25.0}]},
    })

    assert_eq(displaced, [])
    assert_not_null(equipment.equipped(ItemTypes.EquipSlot.BODY))
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), stats.base_stats.get(StatKeys.MAX_HEALTH, 0.0) + 20.0 + 25.0)

func test_load_state_with_an_illegal_item_does_not_equip_it_and_returns_it_displaced():
    var entity := _make_character({StatKeys.MIGHT: 0.0})
    var equipment := EquipmentComponent.of(entity)

    var displaced: Array = equipment.load_state({
        "HELM": {"def_id": "plate_helm", "rarity": int(ItemTypes.Rarity.QUALITY), "affixes": []},
    })

    assert_null(equipment.equipped(ItemTypes.EquipSlot.HELM))
    assert_eq(displaced.size(), 1)
    assert_eq(displaced[0].definition_id, &"plate_helm")
    assert_push_warning("no longer qualifies")

func test_load_state_with_unknown_slot_name_is_ignored():
    var entity := _make_character()
    var equipment := EquipmentComponent.of(entity)

    var displaced: Array = equipment.load_state({
        "NOT_A_SLOT": {"def_id": "worn_hide", "rarity": 0, "affixes": []},
    })

    assert_eq(displaced, [])
    assert_eq(equipment.all_equipped(), {})
