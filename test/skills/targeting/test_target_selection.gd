extends GutTest

const PLAYER := FactionComponent.Faction.PLAYER
const ENEMY := FactionComponent.Faction.ENEMY
const NEUTRAL := FactionComponent.Faction.NEUTRAL

func _make_character(faction: FactionComponent.Faction, position: Vector2, dead: bool = false) -> Node2D:
    var character := Node2D.new()
    character.global_position = position
    var faction_component := FactionComponent.new()
    faction_component.name = "FactionComponent"
    faction_component.faction = faction
    character.add_child(faction_component)
    if dead:
        var stats := StatsComponent.new()
        stats.name = "StatsComponent"
        stats.base_stats = {StatKeys.MAX_HEALTH: 10.0}
        character.add_child(stats)
        var health := HealthComponent.new()
        health.name = "HealthComponent"
        character.add_child(health)
    add_child_autofree(character)
    if dead:
        HealthComponent.of(character).apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    return character

func test_is_hostile_across_all_nine_faction_pairs():
    assert_false(TargetSelection.is_hostile(PLAYER, PLAYER), "player/player")
    assert_true(TargetSelection.is_hostile(PLAYER, ENEMY), "player/enemy")
    assert_false(TargetSelection.is_hostile(PLAYER, NEUTRAL), "player/neutral")
    assert_true(TargetSelection.is_hostile(ENEMY, PLAYER), "enemy/player")
    assert_false(TargetSelection.is_hostile(ENEMY, ENEMY), "enemy/enemy")
    assert_false(TargetSelection.is_hostile(ENEMY, NEUTRAL), "enemy/neutral")
    assert_false(TargetSelection.is_hostile(NEUTRAL, PLAYER), "neutral/player")
    assert_false(TargetSelection.is_hostile(NEUTRAL, ENEMY), "neutral/enemy")
    assert_false(TargetSelection.is_hostile(NEUTRAL, NEUTRAL), "neutral/neutral")

func test_is_allied_across_all_nine_faction_pairs():
    assert_true(TargetSelection.is_allied(PLAYER, PLAYER), "player/player")
    assert_false(TargetSelection.is_allied(PLAYER, ENEMY), "player/enemy")
    assert_false(TargetSelection.is_allied(PLAYER, NEUTRAL), "player/neutral")
    assert_false(TargetSelection.is_allied(ENEMY, PLAYER), "enemy/player")
    assert_true(TargetSelection.is_allied(ENEMY, ENEMY), "enemy/enemy")
    assert_false(TargetSelection.is_allied(ENEMY, NEUTRAL), "enemy/neutral")
    assert_false(TargetSelection.is_allied(NEUTRAL, PLAYER), "neutral/player")
    assert_false(TargetSelection.is_allied(NEUTRAL, ENEMY), "neutral/enemy")
    assert_true(TargetSelection.is_allied(NEUTRAL, NEUTRAL), "neutral/neutral")

func test_find_enemy_snaps_to_aim_point_over_caster_proximity():
    var caster := _make_character(PLAYER, Vector2.ZERO)
    var near := _make_character(ENEMY, Vector2(50, 0))
    var far := _make_character(ENEMY, Vector2(500, 0))

    var result := TargetSelection.find_enemy(caster, Vector2.ZERO, Vector2(500, 0), 600.0)

    assert_eq(result, far)
    assert_ne(result, near)

func test_find_enemy_falls_back_to_nearest_caster_when_aim_is_empty_air():
    var caster := _make_character(PLAYER, Vector2.ZERO)
    var near := _make_character(ENEMY, Vector2(50, 0))
    _make_character(ENEMY, Vector2(500, 0))

    var result := TargetSelection.find_enemy(caster, Vector2.ZERO, Vector2(2000, 2000), 600.0)

    assert_eq(result, near)

func test_find_enemy_range_gates_the_snap_not_just_the_fallback():
    var caster := _make_character(PLAYER, Vector2.ZERO)
    var near := _make_character(ENEMY, Vector2(50, 0))
    _make_character(ENEMY, Vector2(500, 0))

    var result := TargetSelection.find_enemy(caster, Vector2.ZERO, Vector2(500, 0), 200.0)

    assert_eq(result, near, "the far enemy is beyond targeting_range so it must not be snapped to")

func test_find_enemy_faction_filters_before_distance():
    var caster := _make_character(PLAYER, Vector2.ZERO)
    var neutral := _make_character(NEUTRAL, Vector2(100, 0))
    var enemy := _make_character(ENEMY, Vector2(120, 0))

    var result := TargetSelection.find_enemy(caster, Vector2.ZERO, Vector2(100, 0), 600.0)

    assert_eq(result, enemy)
    assert_ne(result, neutral)

func test_find_enemy_never_selects_dead_candidates():
    var caster := _make_character(PLAYER, Vector2.ZERO)
    _make_character(ENEMY, Vector2(50, 0), true)
    var living := _make_character(ENEMY, Vector2(200, 0))

    var result := TargetSelection.find_enemy(caster, Vector2.ZERO, Vector2(50, 0), 600.0)

    assert_eq(result, living)

func test_find_enemy_returns_null_when_nothing_hostile_is_in_range():
    var caster := _make_character(PLAYER, Vector2.ZERO)
    _make_character(ENEMY, Vector2(1000, 0))

    assert_null(TargetSelection.find_enemy(caster, Vector2.ZERO, Vector2.ZERO, 600.0))

func test_find_enemy_zero_range_is_unlimited():
    var caster := _make_character(PLAYER, Vector2.ZERO)
    var far := _make_character(ENEMY, Vector2(5000, 0))

    var result := TargetSelection.find_enemy(caster, Vector2.ZERO, Vector2.ZERO, 0.0)

    assert_eq(result, far)

func test_find_ally_alone_resolves_to_the_caster():
    var caster := _make_character(PLAYER, Vector2.ZERO)

    var result := TargetSelection.find_ally(caster, Vector2.ZERO, Vector2.ZERO, 600.0)

    assert_eq(result, caster)

func test_find_ally_snaps_to_another_ally_over_the_caster():
    var caster := _make_character(PLAYER, Vector2.ZERO)
    var ally := _make_character(PLAYER, Vector2(300, 0))

    var result := TargetSelection.find_ally(caster, Vector2.ZERO, Vector2(300, 0), 600.0)

    assert_eq(result, ally)
