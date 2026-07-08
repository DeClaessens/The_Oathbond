extends GutTest

func test_damage_dealt_spawns_floating_combat_text_at_target_position():
    var spawner: CombatTextSpawner = preload("res://vfx/floating_combat_text/combat_text_spawner.tscn").instantiate()
    add_child_autofree(spawner)

    var target := Node2D.new()
    target.global_position = Vector2(100, 50)
    add_child_autofree(target)

    Events.damage_dealt.emit(null, target, 50, StatKeys.DamageType.EMBER, false)

    assert_eq(spawner.get_child_count(), 1)
    var spawned: FloatingCombatText = spawner.get_child(0)
    assert_eq(spawned.global_position, Vector2(100, 50))
    assert_eq(spawned.get_node("Label").text, "50")

func test_critical_damage_dealt_spawns_crit_styled_floating_combat_text():
    var spawner: CombatTextSpawner = preload("res://vfx/floating_combat_text/combat_text_spawner.tscn").instantiate()
    add_child_autofree(spawner)

    var target := Node2D.new()
    target.global_position = Vector2(100, 50)
    add_child_autofree(target)

    Events.damage_dealt.emit(null, target, 80, StatKeys.DamageType.EMBER, true)

    var spawned: FloatingCombatText = spawner.get_child(0)
    assert_eq(spawned.scale, Vector2.ONE * FloatingCombatText.CRIT_SCALE)
    assert_eq(spawned.get_node("Label").modulate, FloatingCombatText.CRIT_COLOR)
