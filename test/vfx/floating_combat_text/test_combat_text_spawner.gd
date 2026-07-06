extends GutTest

func test_damage_dealt_spawns_floating_combat_text_at_target_position():
    var spawner: CombatTextSpawner = preload("res://vfx/floating_combat_text/combat_text_spawner.tscn").instantiate()
    add_child_autofree(spawner)

    var target := Node2D.new()
    target.global_position = Vector2(100, 50)
    add_child_autofree(target)

    Events.damage_dealt.emit(null, target, 50, StatKeys.DamageType.EMBER)

    assert_eq(spawner.get_child_count(), 1)
    var spawned: FloatingCombatText = spawner.get_child(0)
    assert_eq(spawned.global_position, Vector2(100, 50))
    assert_eq(spawned.get_node("Label").text, "50")
