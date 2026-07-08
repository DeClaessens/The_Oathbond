extends GutTest

## Roll-based tests assert boundaries and invariants over many rolls, never a
## specific randf() outcome.

const ROLLS := 1500

func _sickle() -> ItemDefinition:
    return ItemCatalog.by_id(&"rusted_sickle")

func _range_for(pool: AffixPool, stat: StringName, op: int) -> Array:
    for entry in pool.entries:
        if entry.stat == stat and int(entry.op) == op:
            return [entry.min_value, entry.max_value]
    return []

func test_roll_never_produces_heirloom_and_count_matches_rarity():
    var definition := _sickle()
    var seen := {}
    for i in ROLLS:
        var inst := ItemRoller.roll(definition)
        assert_ne(inst.rarity, ItemTypes.Rarity.HEIRLOOM, "the roller must never produce HEIRLOOM")
        seen[inst.rarity] = true
        var count := inst.rolled_affixes.size()
        match inst.rarity:
            ItemTypes.Rarity.COMMON:
                assert_eq(count, 0, "Common has 0 affixes")
            ItemTypes.Rarity.QUALITY:
                assert_between(count, 1, 2, "Quality has 1-2 affixes")
            ItemTypes.Rarity.MASTERWORK:
                assert_between(count, 3, 5, "Masterwork has 3-5 affixes")
    assert_true(seen.has(ItemTypes.Rarity.COMMON), "Common appeared over %d rolls" % ROLLS)
    assert_true(seen.has(ItemTypes.Rarity.QUALITY), "Quality appeared over %d rolls" % ROLLS)
    assert_true(seen.has(ItemTypes.Rarity.MASTERWORK), "Masterwork appeared over %d rolls" % ROLLS)

func test_rolled_values_fall_within_pool_ranges():
    var definition := _sickle()
    var pool := definition.affix_pool
    for i in ROLLS:
        var inst := ItemRoller.roll(definition)
        for affix in inst.rolled_affixes:
            var span := _range_for(pool, affix.stat, affix.op)
            assert_false(span.is_empty(), "rolled affix %s must come from the pool" % affix.stat)
            if not span.is_empty():
                assert_between(affix.value, span[0], span[1], "%s value in [%s,%s]" % [affix.stat, span[0], span[1]])

func test_an_items_affixes_are_distinct_stat_op_pairs():
    var definition := _sickle()
    for i in ROLLS:
        var inst := ItemRoller.roll(definition)
        var seen := {}
        for affix in inst.rolled_affixes:
            var key := "%s|%d" % [affix.stat, affix.op]
            assert_false(seen.has(key), "no duplicate stat+op on one item")
            seen[key] = true

func test_roll_never_mutates_the_definition_or_pool():
    var definition := _sickle()
    var pool := definition.affix_pool
    var before := pool.entries.size()
    var first_entry_min := pool.entries[0].min_value
    for i in 200:
        ItemRoller.roll(definition)
    assert_eq(pool.entries.size(), before, "pool entry count is unchanged")
    assert_eq(pool.entries[0].min_value, first_entry_min, "pool entry values are unchanged")

func test_null_definition_is_handled_without_crash():
    var inst := ItemRoller.roll(null)
    assert_not_null(inst)
    assert_eq(inst.rolled_affixes.size(), 0)
    assert_push_error("null definition")

func test_definition_id_is_carried_onto_the_instance():
    var inst := ItemRoller.roll(_sickle())
    assert_eq(inst.definition_id, &"rusted_sickle")
