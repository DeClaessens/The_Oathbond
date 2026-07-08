extends GutTest

var inv: InventoryComponent

func before_each():
    inv = InventoryComponent.new()
    add_child_autofree(inv)

func _make_item(id: StringName = &"rusted_sickle") -> ItemInstance:
    var inst := ItemInstance.new()
    inst.definition_id = id
    inst.rarity = ItemTypes.Rarity.QUALITY
    inst.rolled_affixes = [ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 4.0)]
    return inst

func test_add_holds_the_item_and_emits_changed():
    watch_signals(inv)
    var item := _make_item()
    assert_true(inv.add(item))
    assert_eq(inv.size(), 1)
    assert_signal_emitted(inv, "inventory_changed")

func test_add_null_is_refused():
    assert_false(inv.add(null))
    assert_eq(inv.size(), 0)

func test_remove_drops_the_item_and_emits_changed():
    var item := _make_item()
    inv.add(item)
    watch_signals(inv)
    assert_true(inv.remove(item))
    assert_eq(inv.size(), 0)
    assert_signal_emitted(inv, "inventory_changed")

func test_remove_unknown_item_returns_false():
    assert_false(inv.remove(_make_item()))

func test_add_is_refused_at_capacity():
    for i in InventoryComponent.CAPACITY:
        assert_true(inv.add(_make_item()))
    assert_eq(inv.size(), InventoryComponent.CAPACITY)
    assert_false(inv.add(_make_item()), "over-capacity add must be refused")
    assert_eq(inv.size(), InventoryComponent.CAPACITY)

func test_items_returns_a_copy_not_the_backing_array():
    inv.add(_make_item())
    var snapshot := inv.items()
    snapshot.clear()
    assert_eq(inv.size(), 1, "mutating the returned array must not affect the inventory")

func test_save_state_is_an_array_of_dicts():
    inv.add(_make_item(&"rusted_sickle"))
    inv.add(_make_item(&"worn_hide"))
    var state := inv.save_state()
    assert_eq(typeof(state), TYPE_ARRAY)
    assert_eq(state.size(), 2)
    assert_eq(state[0].def_id, "rusted_sickle")

func test_load_state_rebuilds_instances_and_replaces_contents():
    inv.add(_make_item())
    var section := [
        {"def_id": "worn_hide", "rarity": int(ItemTypes.Rarity.MASTERWORK),
         "affixes": [{"stat": "max_health", "op": int(StatModifier.Op.FLAT), "value": 25.0}]},
    ]
    inv.load_state(section)
    assert_eq(inv.size(), 1)
    var restored: ItemInstance = inv.items()[0]
    assert_eq(restored.definition_id, &"worn_hide")
    assert_eq(restored.rarity, ItemTypes.Rarity.MASTERWORK)
    assert_eq(restored.rolled_affixes[0].value, 25.0)

func test_save_load_round_trip_preserves_each_instance():
    var a := _make_item(&"rusted_sickle")
    a.rarity = ItemTypes.Rarity.MASTERWORK
    a.rolled_affixes = [
        ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 6.25),
        ItemAffix.new(&"crit_chance", StatModifier.Op.ADD_PCT, 0.05),
    ]
    inv.add(a)

    var fresh := InventoryComponent.new()
    add_child_autofree(fresh)
    fresh.load_state(inv.save_state())

    assert_eq(fresh.size(), 1)
    var b: ItemInstance = fresh.items()[0]
    assert_eq(b.definition_id, a.definition_id)
    assert_eq(b.rarity, a.rarity)
    assert_eq(b.rolled_affixes.size(), 2)
    assert_eq(b.rolled_affixes[0].value, 6.25)
    assert_eq(b.rolled_affixes[1].stat, &"crit_chance")
