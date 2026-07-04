extends GutTest

func test_fireball_projectile_deals_fire_damage_on_hit():
    var skill: Skill = load("res://skills/library/fireball.tres")
    var effect: SpawnProjectileEffect = skill.effects[0]

    var caster := Node2D.new()
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster.add_child(caster_stats)
    add_child_autofree(caster)

    var target := Node2D.new()
    var target_stats := StatsComponent.new()
    target_stats.name = "StatsComponent"
    target_stats.base_stats = {StatKeys.HEALTH: 100.0}
    target.add_child(target_stats)
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
    assert_eq(projectile.damage_type, StatKeys.DamageType.FIRE)

    projectile._on_body_entered(target)

    assert_eq(target_stats.get_stat(StatKeys.HEALTH), 50.0)

func test_fireball_projectile_ignores_its_own_caster():
    var skill: Skill = load("res://skills/library/fireball.tres")
    var effect: SpawnProjectileEffect = skill.effects[0]

    var caster := Node2D.new()
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster_stats.base_stats = {StatKeys.HEALTH: 100.0}
    caster.add_child(caster_stats)
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

    assert_eq(caster_stats.get_stat(StatKeys.HEALTH), 100.0)
    assert_false(projectile.is_queued_for_deletion())
