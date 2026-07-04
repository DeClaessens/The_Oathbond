extends GutTest

func _make_entity(max_health: float, resist_physical: float = 0.0) -> Node:
    var entity := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {
        StatKeys.MAX_HEALTH: max_health,
        StatKeys.resist(StatKeys.damage_type_name(StatKeys.DamageType.PHYSICAL)): resist_physical,
    }
    entity.add_child(stats)
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    entity.add_child(health)
    add_child_autofree(entity)
    return entity

func test_starts_at_max_health():
    var entity := _make_entity(100.0)
    var health := HealthComponent.of(entity)
    assert_eq(health.current(), 100.0)
    assert_eq(health.fraction(), 1.0)

func test_apply_damage_depletes_current_health():
    var entity := _make_entity(100.0)
    var health := HealthComponent.of(entity)
    health.apply_damage(30.0, StatKeys.DamageType.PHYSICAL, null)
    assert_eq(health.current(), 70.0)

func test_apply_damage_uses_stats_component_resistance():
    var entity := _make_entity(100.0, 5.0)
    var health := HealthComponent.of(entity)
    health.apply_damage(100.0, StatKeys.DamageType.PHYSICAL, null)
    # resist clamps to 0.9, so 100 * (1 - 0.9) = 10 damage taken
    assert_eq(health.current(), 90.0)

func test_apply_damage_clamps_at_zero():
    var entity := _make_entity(50.0)
    var health := HealthComponent.of(entity)
    health.apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    assert_eq(health.current(), 0.0)

func test_health_changed_emits_current_and_max():
    var entity := _make_entity(100.0)
    var health := HealthComponent.of(entity)
    watch_signals(health)
    health.apply_damage(40.0, StatKeys.DamageType.PHYSICAL, null)
    assert_signal_emitted_with_parameters(health, "health_changed", [60.0, 100.0])
