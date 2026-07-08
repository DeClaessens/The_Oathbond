extends GutTest

func _make_instance() -> ItemInstance:
    var inst := ItemInstance.new()
    inst.definition_id = &"rusted_sickle"
    inst.rarity = ItemTypes.Rarity.MASTERWORK
    inst.rolled_affixes = [
        ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 5.5),
        ItemAffix.new(&"crit_chance", StatModifier.Op.ADD_PCT, 0.04),
    ]
    return inst

func test_to_dict_shape_matches_the_save_schema():
    var data := _make_instance().to_dict()
    assert_eq(data.def_id, "rusted_sickle")
    assert_eq(data.rarity, int(ItemTypes.Rarity.MASTERWORK))
    assert_eq(data.affixes.size(), 2)
    assert_eq(data.affixes[0], {"stat": "dmg_ember", "op": int(StatModifier.Op.FLAT), "value": 5.5})

func test_dict_round_trip_preserves_id_rarity_and_each_affix_value():
    var original := _make_instance()
    var restored := ItemInstance.from_dict(original.to_dict())
    assert_eq(restored.definition_id, original.definition_id)
    assert_eq(restored.rarity, original.rarity)
    assert_eq(restored.rolled_affixes.size(), original.rolled_affixes.size())
    for i in original.rolled_affixes.size():
        assert_eq(restored.rolled_affixes[i].stat, original.rolled_affixes[i].stat)
        assert_eq(restored.rolled_affixes[i].op, original.rolled_affixes[i].op)
        assert_eq(restored.rolled_affixes[i].value, original.rolled_affixes[i].value)

func test_definition_resolves_through_the_catalog():
    var inst := _make_instance()
    var def := inst.definition()
    assert_not_null(def)
    assert_eq(def.id, &"rusted_sickle")

func test_instance_is_refcounted_not_a_resource():
    # Untyped vars so `is Resource` is a runtime check, not a static-false error.
    var inst = ItemInstance.new()
    var affix = ItemAffix.new()
    assert_true(inst is RefCounted, "ItemInstance must be RefCounted (ADR-0003)")
    assert_false(inst is Resource, "ItemInstance must never be a Resource")
    assert_true(affix is RefCounted)
    assert_false(affix is Resource)

func test_triple_reads_from_both_affix_and_entry_uniformly():
    var affix := ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 7.0)
    var from_affix := ItemAffix.triple(affix)
    assert_eq(from_affix, {"stat": &"dmg_ember", "op": StatModifier.Op.FLAT, "value": 7.0})

    var entry := AffixEntry.new()
    entry.stat = &"max_health"
    entry.op = StatModifier.Op.FLAT
    entry.min_value = 12.0
    entry.max_value = 40.0
    var from_entry := ItemAffix.triple(entry)
    assert_eq(from_entry, {"stat": &"max_health", "op": StatModifier.Op.FLAT, "value": 12.0},
        "an implicit AffixEntry reads its fixed value from min_value")
