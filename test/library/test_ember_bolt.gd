extends GutTest

func test_ember_bolt_projectile_deals_ember_damage_on_hit():
    var skill: Skill = load("res://skills/library/ember_bolt.tres")
    var effect: SpawnProjectileEffect = skill.effects[0]

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
    assert_eq(projectile.damage, 50.0)
    assert_eq(projectile.damage_type, StatKeys.DamageType.EMBER)

    projectile._on_body_entered(target)

    assert_eq(target_health.current(), 50.0)

func test_ember_bolt_projectile_ignores_its_own_caster():
    var skill: Skill = load("res://skills/library/ember_bolt.tres")
    var effect: SpawnProjectileEffect = skill.effects[0]

    var caster := Node2D.new()
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster_stats.base_stats = {StatKeys.MAX_HEALTH: 100.0}
    caster.add_child(caster_stats)
    var caster_health := HealthComponent.new()
    caster_health.name = "HealthComponent"
    caster.add_child(caster_health)
    add_child_autofree(caster)

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
    projectile._on_body_entered(caster)

    assert_eq(caster_health.current(), 100.0)
    assert_false(projectile.is_queued_for_deletion())

func test_execute_fails_when_projectile_scene_is_not_assigned():
    var effect := SpawnProjectileEffect.new()

    var spawn_parent := Node.new()
    add_child_autofree(spawn_parent)

    var ctx := SkillContext.new()
    ctx.caster_stats = add_child_autofree(StatsComponent.new())
    ctx.spawn_parent = spawn_parent

    var ok := effect.execute(ctx)

    assert_false(ok)
    assert_eq(spawn_parent.get_child_count(), 0)
    assert_push_error("projectile_scene")

func test_execute_fails_when_spawn_parent_is_null():
    var skill: Skill = load("res://skills/library/ember_bolt.tres")
    var effect: SpawnProjectileEffect = skill.effects[0]

    var ctx := SkillContext.new()
    ctx.caster_stats = add_child_autofree(StatsComponent.new())
    ctx.spawn_parent = null

    var ok := effect.execute(ctx)

    assert_false(ok)
    assert_push_error("spawn_parent")
