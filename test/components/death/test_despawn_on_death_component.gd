extends GutTest

func _make_entity(max_health: float) -> Node:
    var entity := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {
        StatKeys.MAX_HEALTH: max_health,
    }
    entity.add_child(stats)
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    entity.add_child(health)
    var despawn := DespawnOnDeathComponent.new()
    despawn.name = "DespawnOnDeathComponent"
    entity.add_child(despawn)
    add_child_autofree(entity)
    return entity

func test_lethal_damage_queues_the_character_for_deletion():
    var entity := _make_entity(50.0)
    HealthComponent.of(entity).apply_damage(50.0, StatKeys.DamageType.PHYSICAL, null)
    assert_true(entity.is_queued_for_deletion())

func test_non_lethal_damage_does_not_despawn():
    var entity := _make_entity(50.0)
    HealthComponent.of(entity).apply_damage(10.0, StatKeys.DamageType.PHYSICAL, null)
    assert_false(entity.is_queued_for_deletion())

func test_ready_with_no_sibling_health_component_does_not_crash():
    var entity := Node.new()
    var despawn := DespawnOnDeathComponent.new()
    despawn.name = "DespawnOnDeathComponent"
    entity.add_child(despawn)
    add_child_autofree(entity)
    assert_push_error("HealthComponent")
