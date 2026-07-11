extends GutTest

var stats: StatsComponent

func before_each():
    stats = StatsComponent.new()

func after_each():
    stats.free()

func test_stat_with_no_modifiers_returns_base():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 100.0)

func test_flat_modifier_adds_to_base():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    var mod := StatModifier.new()
    mod.stat = StatKeys.MOVE_SPEED
    mod.op = StatModifier.Op.FLAT
    mod.value = 25.0
    stats.add_modifier(mod)
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 125.0)

func test_add_pct_modifier_scales_base():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    var mod := StatModifier.new()
    mod.stat = StatKeys.MOVE_SPEED
    mod.op = StatModifier.Op.ADD_PCT
    mod.value = 0.5
    stats.add_modifier(mod)
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 150.0)

func test_mult_pct_modifier_multiplies_base():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    var mod := StatModifier.new()
    mod.stat = StatKeys.MOVE_SPEED
    mod.op = StatModifier.Op.MULT_PCT
    mod.value = 1.0
    stats.add_modifier(mod)
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 200.0)

func test_multiple_mult_pct_modifiers_compound_multiplicatively():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    var mod_a := StatModifier.new()
    mod_a.stat = StatKeys.MOVE_SPEED
    mod_a.op = StatModifier.Op.MULT_PCT
    mod_a.value = 1.0
    var mod_b := StatModifier.new()
    mod_b.stat = StatKeys.MOVE_SPEED
    mod_b.op = StatModifier.Op.MULT_PCT
    mod_b.value = 0.5
    stats.add_modifier(mod_a)
    stats.add_modifier(mod_b)
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 300.0)

func test_flat_add_and_mult_compose_in_bucket_order():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    var flat := StatModifier.new()
    flat.stat = StatKeys.MOVE_SPEED
    flat.op = StatModifier.Op.FLAT
    flat.value = 50.0
    var add := StatModifier.new()
    add.stat = StatKeys.MOVE_SPEED
    add.op = StatModifier.Op.ADD_PCT
    add.value = 0.2
    var mult := StatModifier.new()
    mult.stat = StatKeys.MOVE_SPEED
    mult.op = StatModifier.Op.MULT_PCT
    mult.value = 0.5
    stats.add_modifier(flat)
    stats.add_modifier(add)
    stats.add_modifier(mult)
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 270.0)

func test_scale_outgoing_applies_offensive_modifiers_to_skill_base():
    var mod := StatModifier.new()
    mod.stat = StatKeys.dmg(StatKeys.damage_type_name(StatKeys.DamageType.EMBER))
    mod.op = StatModifier.Op.ADD_PCT
    mod.value = 0.5
    stats.add_modifier(mod)
    assert_eq(stats.scale_outgoing(50.0, StatKeys.DamageType.EMBER), 75.0)

func test_scale_outgoing_with_flat_dmg_modifier_adds_flat_damage():
    var flat := StatModifier.new()
    flat.stat = StatKeys.dmg(StatKeys.damage_type_name(StatKeys.DamageType.EMBER))
    flat.op = StatModifier.Op.FLAT
    flat.value = 10.0
    stats.add_modifier(flat)
    assert_eq(stats.scale_outgoing(50.0, StatKeys.DamageType.EMBER), 60.0)

func test_scale_outgoing_with_add_pct_dmg_modifier_adds_proportional_damage():
    var add := StatModifier.new()
    add.stat = StatKeys.dmg(StatKeys.damage_type_name(StatKeys.DamageType.EMBER))
    add.op = StatModifier.Op.ADD_PCT
    add.value = 0.2
    stats.add_modifier(add)
    assert_eq(stats.scale_outgoing(50.0, StatKeys.DamageType.EMBER), 60.0)

func test_scale_outgoing_composes_flat_and_add_pct_dmg_modifiers():
    var flat := StatModifier.new()
    flat.stat = StatKeys.dmg(StatKeys.damage_type_name(StatKeys.DamageType.EMBER))
    flat.op = StatModifier.Op.FLAT
    flat.value = 10.0
    var add := StatModifier.new()
    add.stat = StatKeys.dmg(StatKeys.damage_type_name(StatKeys.DamageType.EMBER))
    add.op = StatModifier.Op.ADD_PCT
    add.value = 0.2
    stats.add_modifier(flat)
    stats.add_modifier(add)
    assert_eq(stats.scale_outgoing(50.0, StatKeys.DamageType.EMBER), 72.0)

func test_roll_outgoing_with_zero_crit_chance_never_crits():
    stats.base_stats = {StatKeys.CRIT_CHANCE: 0.0, StatKeys.CRIT_MULTI: 2.0}
    var packet := stats.roll_outgoing(50.0, StatKeys.DamageType.EMBER)
    assert_false(packet.is_crit)
    assert_eq(packet.amount, 50.0)

func test_roll_outgoing_with_full_crit_chance_always_crits_and_scales_by_multi():
    stats.base_stats = {StatKeys.CRIT_CHANCE: 1.0, StatKeys.CRIT_MULTI: 2.0}
    var packet := stats.roll_outgoing(50.0, StatKeys.DamageType.EMBER)
    assert_true(packet.is_crit)
    assert_eq(packet.amount, 100.0)
    assert_eq(packet.type, StatKeys.DamageType.EMBER)

func test_roll_outgoing_floors_crit_multi_at_one():
    stats.base_stats = {StatKeys.CRIT_CHANCE: 1.0, StatKeys.CRIT_MULTI: 0.5}
    var packet := stats.roll_outgoing(50.0, StatKeys.DamageType.EMBER)
    assert_true(packet.is_crit)
    assert_eq(packet.amount, 50.0, "crit_multi below 1.0 must be floored so a crit never deals less than a normal hit")

func test_roll_outgoing_composes_scale_outgoing_before_crit():
    stats.base_stats = {StatKeys.CRIT_CHANCE: 1.0, StatKeys.CRIT_MULTI: 2.0}
    var flat := StatModifier.new()
    flat.stat = StatKeys.dmg(StatKeys.damage_type_name(StatKeys.DamageType.EMBER))
    flat.op = StatModifier.Op.FLAT
    flat.value = 10.0
    stats.add_modifier(flat)
    var packet := stats.roll_outgoing(50.0, StatKeys.DamageType.EMBER)
    assert_eq(packet.amount, 120.0, "roll_outgoing must crit-scale scale_outgoing's result, not the raw base")

func test_mitigate_incoming_clamps_resistance_at_0_9():
    stats.base_stats = {
        StatKeys.resist(StatKeys.damage_type_name(StatKeys.DamageType.PHYSICAL)): 5.0,
    }
    assert_almost_eq(stats.mitigate_incoming(100.0, StatKeys.DamageType.PHYSICAL), 10.0, 0.0001)

func test_derived_stat_includes_source_attribute_contribution():
    stats.base_stats = {StatKeys.MIGHT: 10.0}
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), 20.0)

func test_derived_stat_stacks_with_its_own_base():
    stats.base_stats = {StatKeys.MIGHT: 10.0, StatKeys.MAX_HEALTH: 100.0}
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), 120.0)

func test_wit_derives_max_mana_and_grace_derives_crit_multi():
    stats.base_stats = {StatKeys.WIT: 20.0, StatKeys.GRACE: 40.0}
    assert_eq(stats.get_stat(StatKeys.MAX_MANA), 20.0)
    assert_almost_eq(stats.get_stat(StatKeys.CRIT_MULTI), 0.2, 0.0001)

func test_flat_pct_gear_on_derived_stat_amplifies_the_attribute_contribution():
    stats.base_stats = {StatKeys.MIGHT: 10.0}
    var add := StatModifier.new()
    add.stat = StatKeys.MAX_HEALTH
    add.op = StatModifier.Op.ADD_PCT
    add.value = 0.5
    stats.add_modifier(add)
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), 30.0, "FLAT-tier placement means +% max health must also scale Might-derived health")

func test_adding_a_source_attribute_modifier_emits_dependent_stat_changed():
    stats.base_stats = {StatKeys.MIGHT: 10.0}
    watch_signals(stats)
    var mod := StatModifier.new()
    mod.stat = StatKeys.MIGHT
    mod.op = StatModifier.Op.FLAT
    mod.value = 5.0
    stats.add_modifier(mod)

    assert_signal_emitted_with_parameters(stats, "stat_changed", [StatKeys.MIGHT, 15.0], 0)
    assert_signal_emitted_with_parameters(stats, "stat_changed", [StatKeys.MAX_HEALTH, 30.0], 1)

func test_removing_a_source_attribute_modifier_tracks_the_derived_stat_back_down():
    stats.base_stats = {StatKeys.MIGHT: 10.0}
    var mod := StatModifier.new()
    mod.stat = StatKeys.MIGHT
    mod.op = StatModifier.Op.FLAT
    mod.value = 5.0
    stats.add_modifier(mod)
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), 30.0)

    watch_signals(stats)
    stats.remove_modifier(mod)

    assert_signal_emitted_with_parameters(stats, "stat_changed", [StatKeys.MAX_HEALTH, 20.0])
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), 20.0)

func test_refresh_reapply_of_a_source_attribute_emits_the_dependent_stat():
    stats.base_stats = {StatKeys.MIGHT: 10.0}
    var first := StatModifier.new()
    first.stat = StatKeys.MIGHT
    first.op = StatModifier.Op.FLAT
    first.value = 5.0
    first.key = &"attribute_might"
    stats.add_modifier(first)

    watch_signals(stats)
    var refreshed := StatModifier.new()
    refreshed.stat = StatKeys.MIGHT
    refreshed.op = StatModifier.Op.FLAT
    refreshed.value = 8.0
    refreshed.key = &"attribute_might"
    stats.add_modifier(refreshed)

    assert_signal_emitted_with_parameters(stats, "stat_changed", [StatKeys.MAX_HEALTH, 36.0])

func test_expiring_a_timed_source_attribute_modifier_emits_the_dependent_stat():
    stats.base_stats = {StatKeys.MIGHT: 10.0}
    var mod := StatModifier.new()
    mod.stat = StatKeys.MIGHT
    mod.op = StatModifier.Op.FLAT
    mod.value = 5.0
    mod.duration = 1.0
    stats.add_modifier(mod)

    watch_signals(stats)
    stats._process(1.5)

    assert_signal_emitted_with_parameters(stats, "stat_changed", [StatKeys.MAX_HEALTH, 20.0])

func test_stat_with_no_derivation_only_emits_once():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    var mod := StatModifier.new()
    mod.stat = StatKeys.MOVE_SPEED
    mod.op = StatModifier.Op.FLAT
    mod.value = 10.0
    watch_signals(stats)
    stats.add_modifier(mod)
    assert_signal_emit_count(stats, "stat_changed", 1)

func _keyed_mod(value: float, duration: float, op: StatModifier.Op = StatModifier.Op.ADD_PCT) -> StatModifier:
    var mod := StatModifier.new()
    mod.stat = StatKeys.MOVE_SPEED
    mod.op = op
    mod.value = value
    mod.key = &"buff"
    mod.duration = duration
    return mod

func test_refresh_reapply_replaces_value_op_and_duration():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    stats.add_modifier(_keyed_mod(0.2, 5.0))
    var replacement := _keyed_mod(0.5, 10.0, StatModifier.Op.MULT_PCT)
    stats.add_modifier(replacement)

    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 150.0, "reapply must use the new modifier's value/op")
    assert_eq(stats.time_remaining(&"buff"), 10.0, "reapply must refresh duration")

func test_refresh_reapply_updates_source():
    var first_source := Node.new()
    var second_source := Node.new()
    var mod_a := _keyed_mod(0.2, 5.0)
    mod_a.source = first_source
    var mod_b := _keyed_mod(0.3, 5.0)
    mod_b.source = second_source
    stats.add_modifier(mod_a)
    stats.add_modifier(mod_b)

    assert_eq(stats._find_by_key(&"buff").source, second_source)
    first_source.free()
    second_source.free()

func test_stack_mode_stacks_up_to_max_stacks():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    for i in 3:
        var mod := _keyed_mod(0.1, 5.0)
        mod.stack_mode = StatModifier.StackMode.STACK
        mod.max_stacks = 3
        stats.add_modifier(mod)

    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 130.0)

func test_stack_mode_does_not_exceed_max_stacks():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    for i in 5:
        var mod := _keyed_mod(0.1, 5.0)
        mod.stack_mode = StatModifier.StackMode.STACK
        mod.max_stacks = 3
        stats.add_modifier(mod)

    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 130.0)

func test_stack_mode_emits_stat_changed_on_each_application():
    var mod := _keyed_mod(0.1, 5.0)
    mod.stack_mode = StatModifier.StackMode.STACK
    mod.max_stacks = 3
    watch_signals(stats)
    stats.add_modifier(mod)
    assert_signal_emit_count(stats, "stat_changed", 1)

func test_remove_by_source_erases_only_that_sources_mods_and_emits_once_per_stat():
    stats.base_stats = {StatKeys.MIGHT: 10.0, StatKeys.MOVE_SPEED: 100.0}
    var source_a := RefCounted.new()
    var source_b := RefCounted.new()
    var a1 := StatModifier.new()
    a1.stat = StatKeys.MIGHT
    a1.op = StatModifier.Op.FLAT
    a1.value = 5.0
    a1.source = source_a
    var a2 := StatModifier.new()
    a2.stat = StatKeys.MOVE_SPEED
    a2.op = StatModifier.Op.FLAT
    a2.value = 20.0
    a2.source = source_a
    var a3 := StatModifier.new()
    a3.stat = StatKeys.MOVE_SPEED
    a3.op = StatModifier.Op.ADD_PCT
    a3.value = 0.1
    a3.source = source_a
    var b1 := StatModifier.new()
    b1.stat = StatKeys.MOVE_SPEED
    b1.op = StatModifier.Op.FLAT
    b1.value = 50.0
    b1.source = source_b
    stats.add_modifier(a1)
    stats.add_modifier(a2)
    stats.add_modifier(a3)
    stats.add_modifier(b1)

    watch_signals(stats)
    stats.remove_by_source(source_a)

    # Only source_b's modifier survives.
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 150.0, "source_b's flat +50 must remain, source_a's must be gone")
    assert_eq(stats.get_stat(StatKeys.MIGHT), 10.0, "source_a's +5 Might must be gone")
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), 20.0, "the dependent derived stat must track Might back down")
    # One emission for might, one for its dependent max_health, one for move_speed --
    # in that order (MIGHT is processed before MOVE_SPEED in `affected`).
    assert_signal_emit_count(stats, "stat_changed", 3)
    assert_signal_emitted_with_parameters(stats, "stat_changed", [StatKeys.MIGHT, 10.0], 0)
    assert_signal_emitted_with_parameters(stats, "stat_changed", [StatKeys.MAX_HEALTH, 20.0], 1)
    assert_signal_emitted_with_parameters(stats, "stat_changed", [StatKeys.MOVE_SPEED, 150.0], 2)

func test_remove_by_source_with_no_matching_mods_is_a_silent_no_op():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    var mod := StatModifier.new()
    mod.stat = StatKeys.MOVE_SPEED
    mod.op = StatModifier.Op.FLAT
    mod.value = 10.0
    mod.source = RefCounted.new()
    stats.add_modifier(mod)

    watch_signals(stats)
    stats.remove_by_source(RefCounted.new())

    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 110.0)
    assert_signal_emit_count(stats, "stat_changed", 0)

func test_stack_mode_stacks_expire_independently():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    var mod_a := _keyed_mod(0.1, 1.0)
    mod_a.stack_mode = StatModifier.StackMode.STACK
    mod_a.max_stacks = 2
    var mod_b := _keyed_mod(0.1, 10.0)
    mod_b.stack_mode = StatModifier.StackMode.STACK
    mod_b.max_stacks = 2
    stats.add_modifier(mod_a)
    stats.add_modifier(mod_b)

    stats._process(1.5)

    assert_almost_eq(stats.get_stat(StatKeys.MOVE_SPEED), 110.0, 0.0001)
