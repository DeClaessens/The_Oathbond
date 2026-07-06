extends GutTest

func _make_entity(max_mana: float, mana_regen: float = 0.0) -> Node:
    var entity := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {
        StatKeys.MAX_MANA: max_mana,
        StatKeys.MANA_REGEN: mana_regen,
    }
    entity.add_child(stats)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    entity.add_child(mana)
    add_child_autofree(entity)
    return entity

func test_starts_at_max_mana():
    var entity := _make_entity(100.0)
    var mana := ManaComponent.of(entity)
    assert_eq(mana.current(), 100.0)
    assert_eq(mana.fraction(), 1.0)

func test_spend_depletes_current_mana():
    var entity := _make_entity(100.0)
    var mana := ManaComponent.of(entity)
    mana.spend(30.0)
    assert_eq(mana.current(), 70.0)

func test_spend_clamps_at_zero():
    var entity := _make_entity(50.0)
    var mana := ManaComponent.of(entity)
    mana.spend(999.0)
    assert_eq(mana.current(), 0.0)

func test_can_afford_reflects_current_mana():
    var entity := _make_entity(50.0)
    var mana := ManaComponent.of(entity)
    assert_true(mana.can_afford(50.0))
    assert_false(mana.can_afford(50.1))

func test_mana_changed_emits_current_and_max():
    var entity := _make_entity(100.0)
    var mana := ManaComponent.of(entity)
    watch_signals(mana)
    mana.spend(40.0)
    assert_signal_emitted_with_parameters(mana, "mana_changed", [60.0, 100.0])

func test_process_regenerates_at_mana_regen_rate():
    var entity := _make_entity(100.0, 10.0)
    var mana := ManaComponent.of(entity)
    mana.spend(50.0)
    mana._process(1.0)
    assert_eq(mana.current(), 60.0)

func test_process_does_not_regen_past_max():
    var entity := _make_entity(100.0, 10.0)
    var mana := ManaComponent.of(entity)
    mana.spend(5.0)
    mana._process(1.0)
    assert_eq(mana.current(), 100.0)

func test_process_does_not_emit_when_already_at_max():
    var entity := _make_entity(100.0, 10.0)
    var mana := ManaComponent.of(entity)
    watch_signals(mana)
    mana._process(1.0)
    assert_signal_not_emitted(mana, "mana_changed")

func test_ready_with_no_sibling_stats_component_does_not_crash():
    var entity := Node.new()
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    entity.add_child(mana)
    add_child_autofree(entity)

    assert_push_error("StatsComponent")
    assert_eq(mana.current(), 0.0)
    assert_eq(mana.max_mana(), 0.0)
    assert_false(mana.can_afford(1.0))

func test_restore_full_refills_current_mana():
    var entity := _make_entity(100.0)
    var mana := ManaComponent.of(entity)
    mana.spend(60.0)
    mana.restore_full()
    assert_eq(mana.current(), 100.0)
