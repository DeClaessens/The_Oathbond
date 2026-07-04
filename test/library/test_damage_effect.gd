extends GutTest

func test_damage_effect_deals_scaled_damage_to_targets():
    var effect := DamageEffect.new()
    effect.base_amount = 50
    effect.damage_type = StatKeys.DamageType.FIRE

    var caster := Node2D.new()
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster.add_child(caster_stats)
    add_child_autofree(caster)

    var target := Node2D.new()
    var target_stats := StatsComponent.new()
    target_stats.name = "StatsComponent"
    target_stats.base_stats = {StatKeys.MAX_HEALTH: 100.0}
    target.add_child(target_stats)
    var target_health := HealthComponent.new()
    target_health.name = "HealthComponent"
    target.add_child(target_health)
    add_child_autofree(target)

    var ctx := SkillContext.new()
    ctx.caster = caster
    ctx.caster_stats = caster_stats
    ctx.targets = [target] as Array[Node]

    var ok := effect.execute(ctx)

    assert_true(ok)
    assert_eq(target_health.current(), 50.0)

func test_negative_base_amount_does_not_heal_the_target():
    var effect := DamageEffect.new()
    effect.base_amount = -50
    effect.damage_type = StatKeys.DamageType.FIRE

    var caster := Node2D.new()
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster.add_child(caster_stats)
    add_child_autofree(caster)

    var target := Node2D.new()
    var target_stats := StatsComponent.new()
    target_stats.name = "StatsComponent"
    target_stats.base_stats = {StatKeys.MAX_HEALTH: 100.0}
    target.add_child(target_stats)
    var target_health := HealthComponent.new()
    target_health.name = "HealthComponent"
    target.add_child(target_health)
    add_child_autofree(target)

    var ctx := SkillContext.new()
    ctx.caster = caster
    ctx.caster_stats = caster_stats
    ctx.targets = [target] as Array[Node]

    effect.execute(ctx)

    assert_eq(target_health.current(), 100.0)

func test_execute_fails_without_caster_stats():
    var effect := DamageEffect.new()
    var ctx := SkillContext.new()
    ctx.caster_stats = null
    ctx.targets = [] as Array[Node]

    var ok := effect.execute(ctx)

    assert_false(ok)
    assert_push_error("caster_stats")
