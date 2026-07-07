extends GutTest

func test_smite_deals_direct_physical_damage_to_its_target():
    var skill: Skill = load("res://skills/library/smite.tres")
    var effect: DamageEffect = skill.effects[0]

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

    assert_eq(target_health.current(), 75.0)

func test_smite_targeting_resolves_the_nearest_enemy_in_range():
    var skill: Skill = load("res://skills/library/smite.tres")
    assert_eq(skill.targeting, Skill.Targeting.ENEMY)

    var caster := Node2D.new()
    var caster_faction := FactionComponent.new()
    caster_faction.name = "FactionComponent"
    caster_faction.faction = FactionComponent.Faction.PLAYER
    caster.add_child(caster_faction)
    add_child_autofree(caster)

    var enemy := Node2D.new()
    enemy.global_position = Vector2(100, 0)
    var enemy_faction := FactionComponent.new()
    enemy_faction.name = "FactionComponent"
    enemy_faction.faction = FactionComponent.Faction.ENEMY
    enemy.add_child(enemy_faction)
    add_child_autofree(enemy)

    var result := AbilityComponent._resolve_activation(skill, true, true, true, caster, Vector2.ZERO, Vector2(100, 0))

    assert_true(result.ok)
    assert_eq(result.targets, [enemy] as Array[Node])
