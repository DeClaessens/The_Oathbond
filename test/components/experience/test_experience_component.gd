extends GutTest

func _make_character(max_health: float = 100.0, max_mana: float = 50.0) -> Node:
    var entity := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {
        StatKeys.MAX_HEALTH: max_health,
        StatKeys.MAX_MANA: max_mana,
    }
    entity.add_child(stats)
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    entity.add_child(health)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    entity.add_child(mana)
    var xp := ExperienceComponent.new()
    xp.name = "ExperienceComponent"
    entity.add_child(xp)
    add_child_autofree(entity)
    return entity

func _make_victim(reward_amount: int) -> Node:
    var victim := Node.new()
    var reward := XpRewardComponent.new()
    reward.name = "XpRewardComponent"
    reward.amount = reward_amount
    victim.add_child(reward)
    add_child_autofree(victim)
    return victim

func test_starts_at_level_one_with_zero_xp():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)
    assert_eq(xp.level(), 1)
    assert_eq(xp.xp(), 0)

func test_killing_victim_with_reward_grants_xp():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)
    var victim := _make_victim(10)

    Events.character_died.emit(victim, entity)

    assert_eq(xp.xp(), 10)

func test_null_killer_grants_nothing():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)
    var victim := _make_victim(10)

    Events.character_died.emit(victim, null)

    assert_eq(xp.xp(), 0)

func test_other_killer_grants_nothing():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)
    var other := Node.new()
    add_child_autofree(other)
    var victim := _make_victim(10)

    Events.character_died.emit(victim, other)

    assert_eq(xp.xp(), 0)

func test_self_kill_grants_nothing():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)
    var reward := XpRewardComponent.new()
    reward.name = "XpRewardComponent"
    reward.amount = 10
    entity.add_child(reward)

    Events.character_died.emit(entity, entity)

    assert_eq(xp.xp(), 0)

func test_victim_without_reward_component_grants_nothing():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)
    var victim := Node.new()
    add_child_autofree(victim)

    Events.character_died.emit(victim, entity)

    assert_eq(xp.xp(), 0)

func test_award_exactly_the_threshold_levels_up_with_full_pools():
    var entity := _make_character(100.0, 50.0)
    var xp := ExperienceComponent.of(entity)
    var health := HealthComponent.of(entity)
    var stats := StatsComponent.of(entity)
    health.apply_damage(90.0, StatKeys.DamageType.PHYSICAL, null)

    watch_signals(xp)
    xp.award_xp(xp.xp_to_next(1))

    assert_eq(xp.level(), 2)
    assert_eq(xp.xp(), 0)
    assert_signal_emitted_with_parameters(xp, "leveled_up", [2])
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), 110.0)
    assert_eq(stats.get_stat(StatKeys.MAX_MANA), 55.0)
    assert_eq(health.current(), 110.0, "level-up must fully restore health")

func test_overflow_award_grants_multiple_levels_with_carry_over():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)

    var total := xp.xp_to_next(1) + xp.xp_to_next(2) + 3
    xp.award_xp(total)

    assert_eq(xp.level(), 3)
    assert_eq(xp.xp(), 3)

func test_ten_level_ups_stack_flat_health_bonus():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)
    var stats := StatsComponent.of(entity)

    for level in range(1, 11):
        xp.award_xp(xp.xp_to_next(xp.level()))

    assert_eq(xp.level(), 11)
    assert_eq(stats.get_stat(StatKeys.MAX_HEALTH), 200.0, "ten level-ups must stack, not refresh")

func test_award_zero_or_negative_xp_does_nothing():
    var entity := _make_character()
    var xp := ExperienceComponent.of(entity)
    watch_signals(xp)

    xp.award_xp(0)
    xp.award_xp(-5)

    assert_eq(xp.xp(), 0)
    assert_signal_not_emitted(xp, "experience_changed")

func test_kill_through_ember_bolt_projectile_credits_the_caster():
    var skill: Skill = load("res://skills/library/ember_bolt.tres")
    var effect: SpawnProjectileEffect = skill.effects[0]

    var caster := Node2D.new()
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster.add_child(caster_stats)
    var caster_xp := ExperienceComponent.new()
    caster_xp.name = "ExperienceComponent"
    caster.add_child(caster_xp)
    add_child_autofree(caster)

    var target := Node2D.new()
    var target_stats := StatsComponent.new()
    target_stats.name = "StatsComponent"
    target_stats.base_stats = {StatKeys.MAX_HEALTH: 40.0}
    target.add_child(target_stats)
    var target_health := HealthComponent.new()
    target_health.name = "HealthComponent"
    target.add_child(target_health)
    var target_reward := XpRewardComponent.new()
    target_reward.name = "XpRewardComponent"
    target_reward.amount = 10
    target.add_child(target_reward)
    add_child_autofree(target)

    var spawn_parent := Node.new()
    add_child_autofree(spawn_parent)

    var ctx := SkillContext.new()
    ctx.caster = caster
    ctx.caster_stats = caster_stats
    ctx.source_position = Vector2.ZERO
    ctx.aim_direction = Vector2.RIGHT
    ctx.spawn_parent = spawn_parent

    effect.execute(ctx)

    var projectile: Projectile = spawn_parent.get_child(0)
    projectile._on_body_entered(target)

    assert_true(target_health.is_dead())
    assert_eq(caster_xp.xp(), 10, "a lethal ember bolt must credit the casting character, not the projectile")
