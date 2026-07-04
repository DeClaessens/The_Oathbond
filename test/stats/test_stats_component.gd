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

func test_apply_damage_clamps_resistance_at_0_9():
    stats.base_stats = {
        StatKeys.HEALTH: 100.0,
        StatKeys.resist(StatKeys.damage_type_name(StatKeys.DamageType.PHYSICAL)): 5.0,
    }
    stats.apply_damage(100.0, StatKeys.DamageType.PHYSICAL, null)
    # resist clamps to 0.9, so 100 * (1 - 0.9) = 10 damage taken
    assert_eq(stats.base_stats[StatKeys.HEALTH], 90.0)
