extends GutTest

const PlayerScene := preload("res://entities/player/Player.tscn")

func test_death_respawns_at_spawn_point_with_full_pools():
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)
    var spawn := player.global_position
    var health := HealthComponent.of(player)
    var mana := ManaComponent.of(player)

    player.global_position = spawn + Vector2(500.0, 0.0)
    mana.spend(40.0)
    health.apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)

    assert_eq(player.global_position, spawn)
    assert_eq(health.current(), health.max_health())
    assert_false(health.is_dead())
    assert_eq(mana.current(), mana.max_mana())
