extends GutTest

const PLAYER := FactionComponent.Faction.PLAYER
const ENEMY := FactionComponent.Faction.ENEMY

func _make_bite_skill() -> Skill:
    var skill := Skill.new()
    skill.id = &"test_bite"
    skill.targeting = Skill.Targeting.ENEMY
    skill.targeting_range = 90.0
    skill.cooldown = 1.0
    var effect := DamageEffect.new()
    effect.base_amount = 8
    skill.effects = [effect] as Array[SkillEffect]
    return skill

func _make_ai(position: Vector2, aggro_range: float = 400.0, skill: Skill = null) -> CharacterBody2D:
    var body := CharacterBody2D.new()
    body.global_position = position

    var faction := FactionComponent.new()
    faction.name = "FactionComponent"
    faction.faction = ENEMY
    body.add_child(faction)

    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0, StatKeys.MAX_HEALTH: 50.0}
    body.add_child(stats)

    var health := HealthComponent.new()
    health.name = "HealthComponent"
    body.add_child(health)

    var abilities := AbilityComponent.new()
    abilities.name = "AbilityComponent"
    body.add_child(abilities)

    var ai := AiControllerComponent.new()
    ai.name = "AiControllerComponent"
    ai.aggro_range = aggro_range
    ai.skill = skill
    body.add_child(ai)

    add_child_autofree(body)
    return body

func _make_target(faction: FactionComponent.Faction, position: Vector2) -> Node2D:
    var target := Node2D.new()
    target.global_position = position

    var faction_component := FactionComponent.new()
    faction_component.name = "FactionComponent"
    faction_component.faction = faction
    target.add_child(faction_component)

    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {StatKeys.MAX_HEALTH: 100.0}
    target.add_child(stats)

    var health := HealthComponent.new()
    health.name = "HealthComponent"
    target.add_child(health)

    add_child_autofree(target)
    return target

func test_no_hostile_in_range_keeps_ai_idle_with_zero_velocity():
    var ai_body := _make_ai(Vector2.ZERO)
    _make_target(PLAYER, Vector2(5000, 0))
    var ai := ai_body.get_node(^"AiControllerComponent") as AiControllerComponent

    ai._physics_process(0.016)

    assert_eq(ai.state, AiControllerComponent.State.IDLE)
    assert_eq(ai_body.velocity.x, 0.0)

func test_target_within_aggro_range_but_outside_skill_range_triggers_chase():
    var ai_body := _make_ai(Vector2.ZERO, 400.0, _make_bite_skill())
    _make_target(PLAYER, Vector2(300, 0))
    var ai := ai_body.get_node(^"AiControllerComponent") as AiControllerComponent

    ai._physics_process(0.016)

    assert_eq(ai.state, AiControllerComponent.State.CHASE)
    assert_gt(ai_body.velocity.x, 0.0, "should walk toward the target on its right")

func test_target_leaving_aggro_range_returns_ai_to_idle():
    var ai_body := _make_ai(Vector2.ZERO, 400.0)
    var target := _make_target(PLAYER, Vector2(300, 0))
    var ai := ai_body.get_node(^"AiControllerComponent") as AiControllerComponent

    ai._physics_process(0.016)
    assert_eq(ai.state, AiControllerComponent.State.CHASE)

    target.global_position = Vector2(9999, 0)
    ai._physics_process(0.016)

    assert_eq(ai.state, AiControllerComponent.State.IDLE)
    assert_eq(ai_body.velocity.x, 0.0)

func test_target_within_skill_range_triggers_attack_and_damages_target():
    var ai_body := _make_ai(Vector2.ZERO, 400.0, _make_bite_skill())
    var target := _make_target(PLAYER, Vector2(50, 0))
    var ai := ai_body.get_node(^"AiControllerComponent") as AiControllerComponent
    var abilities := ai_body.get_node(^"AbilityComponent") as AbilityComponent
    var target_health := HealthComponent.of(target)

    watch_signals(abilities)
    ai._physics_process(0.016)

    assert_eq(ai.state, AiControllerComponent.State.ATTACK)
    assert_eq(ai_body.velocity.x, 0.0)
    assert_signal_emitted(abilities, "skill_activated")
    assert_lt(target_health.current(), 100.0)

func test_dead_target_is_ignored_and_ai_returns_to_idle():
    var ai_body := _make_ai(Vector2.ZERO, 400.0, _make_bite_skill())
    var target := _make_target(PLAYER, Vector2(50, 0))
    var ai := ai_body.get_node(^"AiControllerComponent") as AiControllerComponent
    var abilities := ai_body.get_node(^"AbilityComponent") as AbilityComponent

    HealthComponent.of(target).apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)

    watch_signals(abilities)
    ai._physics_process(0.016)

    assert_eq(ai.state, AiControllerComponent.State.IDLE)
    assert_signal_not_emitted(abilities, "skill_activated")
