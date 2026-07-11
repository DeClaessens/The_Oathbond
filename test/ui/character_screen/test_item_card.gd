extends GutTest

## Pure-arithmetic coverage of ItemCard.mod_deltas (BLUEPRINT.md's Delta
## rules) -- no scene tree needed, matching the project norm of logic-level
## tests for UI arithmetic.

func _item(def_id: StringName, affixes: Array = []) -> ItemInstance:
    var inst := ItemInstance.new()
    inst.definition_id = def_id
    inst.rarity = ItemTypes.Rarity.QUALITY
    inst.rolled_affixes.assign(affixes)
    return inst

func _find(deltas: Array, stat: StringName) -> Dictionary:
    for d in deltas:
        if d.stat == stat:
            return d
    return {}

func test_gain_when_candidate_has_more_than_equipped():
    var candidate := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 8.0)])
    var equipped := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 3.0)])

    var deltas := ItemCard.mod_deltas(candidate, equipped)

    var d := _find(deltas, &"dmg_ember")
    assert_almost_eq(d.delta, 5.0, 0.0001)
    assert_true(d.gain)

func test_loss_when_candidate_has_less_than_equipped():
    var candidate := _item(&"rusted_sickle", [ItemAffix.new(&"crit_chance", StatModifier.Op.ADD_PCT, 0.02)])
    var equipped := _item(&"rusted_sickle", [ItemAffix.new(&"crit_chance", StatModifier.Op.ADD_PCT, 0.05)])

    var deltas := ItemCard.mod_deltas(candidate, equipped)

    var d := _find(deltas, &"crit_chance")
    assert_almost_eq(d.delta, -0.03, 0.0001)
    assert_false(d.gain)

func test_equal_values_are_omitted():
    var candidate := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 5.0)])
    var equipped := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 5.0)])

    var deltas := ItemCard.mod_deltas(candidate, equipped)

    assert_eq(deltas, [])

func test_candidate_only_stat_is_a_pure_gain():
    var candidate := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_radiance", StatModifier.Op.FLAT, 4.0)])
    var equipped := _item(&"rusted_sickle", [])

    var deltas := ItemCard.mod_deltas(candidate, equipped)

    var d := _find(deltas, &"dmg_radiance")
    assert_almost_eq(d.delta, 4.0, 0.0001)
    assert_true(d.gain)

func test_equipped_only_stat_is_a_pure_loss():
    var candidate := _item(&"rusted_sickle", [])
    var equipped := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_rot", StatModifier.Op.FLAT, 6.0)])

    var deltas := ItemCard.mod_deltas(candidate, equipped)

    var d := _find(deltas, &"dmg_rot")
    assert_almost_eq(d.delta, -6.0, 0.0001)
    assert_false(d.gain)

func test_no_equipped_item_nets_every_candidate_mod_as_a_gain():
    var candidate := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 5.0)])

    var deltas := ItemCard.mod_deltas(candidate, null)

    var d := _find(deltas, &"dmg_ember")
    assert_almost_eq(d.delta, 5.0, 0.0001)
    assert_true(d.gain)

func test_same_stat_different_ops_are_tracked_separately():
    var candidate := _item(&"rusted_sickle", [
        ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 5.0),
        ItemAffix.new(&"dmg_ember", StatModifier.Op.ADD_PCT, 0.1),
    ])
    var equipped := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 2.0)])

    var deltas := ItemCard.mod_deltas(candidate, equipped)

    assert_eq(deltas.size(), 2)
    var flat_line: Dictionary = deltas.filter(func(d): return d.op == StatModifier.Op.FLAT)[0]
    var pct_line: Dictionary = deltas.filter(func(d): return d.op == StatModifier.Op.ADD_PCT)[0]
    assert_almost_eq(flat_line.delta, 3.0, 0.0001)
    assert_almost_eq(pct_line.delta, 0.1, 0.0001)

func test_multiple_affixes_on_the_same_stat_and_op_sum_before_comparing():
    var candidate := _item(&"rusted_sickle", [
        ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 3.0),
        ItemAffix.new(&"dmg_ember", StatModifier.Op.FLAT, 4.0),
    ])
    var equipped := _item(&"rusted_sickle", [])

    var deltas := ItemCard.mod_deltas(candidate, equipped)

    var d := _find(deltas, &"dmg_ember")
    assert_almost_eq(d.delta, 7.0, 0.0001)

func test_implicit_mods_from_the_definition_are_included():
    # rusted_sickle's implicit_mods carries a fixed +6 dmg_physical.
    var candidate := _item(&"rusted_sickle", [])
    var equipped := _item(&"rusted_sickle", [ItemAffix.new(&"dmg_physical", StatModifier.Op.FLAT, 6.0)])

    var deltas := ItemCard.mod_deltas(candidate, equipped)

    # Both sides carry the same +6 implicit, plus equipped's own +6 rolled --
    # net delta must be the rolled affix only, not double-counting the implicit.
    var d := _find(deltas, &"dmg_physical")
    assert_almost_eq(d.delta, -6.0, 0.0001)
