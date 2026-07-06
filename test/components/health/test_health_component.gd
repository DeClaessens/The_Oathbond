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

func test_apply_damage_clamps_negative_raw_damage_to_zero():
    var entity := _make_entity(100.0)
    var health := HealthComponent.of(entity)
    health.apply_damage(-30.0, StatKeys.DamageType.PHYSICAL, null)
    assert_eq(health.current(), 100.0, "negative raw damage must not heal")

func test_apply_damage_clamps_over_reduced_damage_to_zero():
    var entity := _make_entity(100.0)
    var health := HealthComponent.of(entity)
    health.apply_damage(-1.0, StatKeys.DamageType.PHYSICAL, null)
    assert_eq(health.current(), 100.0, "over-reduced damage must not heal")

func test_apply_zero_damage_does_not_change_health_or_emit_negative():
    var entity := _make_entity(100.0)
    var health := HealthComponent.of(entity)
    watch_signals(health)
    health.apply_damage(0.0, StatKeys.DamageType.PHYSICAL, null)
    assert_eq(health.current(), 100.0)
    assert_signal_emitted_with_parameters(health, "health_changed", [100.0, 100.0])

func test_damage_dealt_emits_the_entity_root_as_target_not_owner():
    var entity := _make_entity(100.0)
    var health := HealthComponent.of(entity)
    var source := Node.new()
    add_child_autofree(source)
    watch_signals(Events)
    health.apply_damage(30.0, StatKeys.DamageType.PHYSICAL, source)
    assert_signal_emitted_with_parameters(Events, "damage_dealt", [source, entity, 30, StatKeys.DamageType.PHYSICAL])

func test_ready_with_no_sibling_stats_component_does_not_crash():
    var entity := Node.new()
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    entity.add_child(health)
    add_child_autofree(entity)

    assert_push_error("StatsComponent")

func test_apply_damage_before_ready_does_not_crash():
    var health: HealthComponent = autofree(HealthComponent.new())
    health.apply_damage(10.0, StatKeys.DamageType.PHYSICAL, null)
    assert_push_error("StatsComponent")
    assert_eq(health.current(), 0.0)

func test_lethal_damage_emits_died():
    var entity := _make_entity(50.0)
    var health := HealthComponent.of(entity)
    watch_signals(health)
    health.apply_damage(50.0, StatKeys.DamageType.PHYSICAL, null)
    assert_signal_emitted(health, "died")
    assert_true(health.is_dead())

func test_non_lethal_damage_does_not_emit_died():
    var entity := _make_entity(50.0)
    var health := HealthComponent.of(entity)
    watch_signals(health)
    health.apply_damage(49.0, StatKeys.DamageType.PHYSICAL, null)
    assert_signal_not_emitted(health, "died")
    assert_false(health.is_dead())

func test_damage_after_death_is_ignored_and_died_emits_once():
    var entity := _make_entity(50.0)
    var health := HealthComponent.of(entity)
    watch_signals(health)
    health.apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    health.apply_damage(10.0, StatKeys.DamageType.PHYSICAL, null)
    assert_signal_emit_count(health, "died", 1)
    assert_signal_emit_count(health, "health_changed", 1, "damage on a dead character must not re-emit health_changed")
    assert_eq(health.current(), 0.0)

func test_lethal_damage_emits_character_died_with_victim_and_killer():
    var entity := _make_entity(50.0)
    var health := HealthComponent.of(entity)
    var killer := Node.new()
    add_child_autofree(killer)
    watch_signals(Events)
    health.apply_damage(50.0, StatKeys.DamageType.PHYSICAL, killer)
    assert_signal_emitted_with_parameters(Events, "character_died", [entity, killer])

func test_restore_full_resets_health_and_death_state():
    var entity := _make_entity(50.0)
    var health := HealthComponent.of(entity)
    health.apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    health.restore_full()
    assert_eq(health.current(), 50.0)
    assert_false(health.is_dead())
    watch_signals(health)
    health.apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    assert_signal_emitted(health, "died", "a restored character must be able to die again")
