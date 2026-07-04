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
    # 100 * (1+1.0) * (1+0.5) = 300 -- multiplicative buckets compound, they don't sum
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
    # (100 + 50) * (1 + 0.2) * (1 + 0.5) = 270 -- ADR-0001's bucket order
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 270.0)

func test_scale_outgoing_applies_offensive_modifiers_to_skill_base():
    var mod := StatModifier.new()
    mod.stat = StatKeys.dmg(StatKeys.damage_type_name(StatKeys.DamageType.FIRE))
    mod.op = StatModifier.Op.ADD_PCT
    mod.value = 0.5
    stats.add_modifier(mod)
    assert_eq(stats.scale_outgoing(50.0, StatKeys.DamageType.FIRE), 75.0)

func test_mitigate_incoming_clamps_resistance_at_0_9():
    stats.base_stats = {
        StatKeys.resist(StatKeys.damage_type_name(StatKeys.DamageType.PHYSICAL)): 5.0,
    }
    # resist clamps to 0.9, so 100 * (1 - 0.9) = 10 damage taken
    assert_almost_eq(stats.mitigate_incoming(100.0, StatKeys.DamageType.PHYSICAL), 10.0, 0.0001)

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

    # three 10% additive stacks: 100 * (1 + 0.3) = 130
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 130.0)

func test_stack_mode_does_not_exceed_max_stacks():
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    for i in 5:
        var mod := _keyed_mod(0.1, 5.0)
        mod.stack_mode = StatModifier.StackMode.STACK
        mod.max_stacks = 3
        stats.add_modifier(mod)

    # capped at 3 stacks regardless of how many times it was applied
    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), 130.0)

func test_stack_mode_emits_stat_changed_on_each_application():
    var mod := _keyed_mod(0.1, 5.0)
    mod.stack_mode = StatModifier.StackMode.STACK
    mod.max_stacks = 3
    watch_signals(stats)
    stats.add_modifier(mod)
    assert_signal_emit_count(stats, "stat_changed", 1)

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

    # the short-lived stack expired, the long-lived one remains
    assert_almost_eq(stats.get_stat(StatKeys.MOVE_SPEED), 110.0, 0.0001)
