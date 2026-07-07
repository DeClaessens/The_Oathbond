extends GutTest

const PLAYER := FactionComponent.Faction.PLAYER
const ENEMY := FactionComponent.Faction.ENEMY

func _make_caster(enemy_skill: Skill = null, slot: int = 2) -> Node2D:
    var caster := Node2D.new()
    var faction := FactionComponent.new()
    faction.name = "FactionComponent"
    faction.faction = PLAYER
    caster.add_child(faction)
    var abilities := AbilityComponent.new()
    abilities.name = "AbilityComponent"
    caster.add_child(abilities)
    var preview := TargetPreviewComponent.new()
    preview.name = "TargetPreviewComponent"
    caster.add_child(preview)
    add_child_autofree(caster)
    if enemy_skill != null:
        abilities.equip(enemy_skill, slot)
    return caster

func _make_enemy(position: Vector2, dead: bool = false) -> Node2D:
    var enemy := Node2D.new()
    enemy.global_position = position
    var icon := Sprite2D.new()
    icon.name = "Icon"
    enemy.add_child(icon)
    var faction := FactionComponent.new()
    faction.name = "FactionComponent"
    faction.faction = ENEMY
    enemy.add_child(faction)
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {StatKeys.MAX_HEALTH: 10.0}
    enemy.add_child(stats)
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    enemy.add_child(health)
    var highlight := HighlightComponent.new()
    highlight.name = "HighlightComponent"
    enemy.add_child(highlight)
    add_child_autofree(enemy)
    if dead:
        health.apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    return enemy

func _enemy_skill(range: float = 600.0) -> Skill:
    var skill := Skill.new()
    skill.targeting = Skill.Targeting.ENEMY
    skill.targeting_range = range
    return skill

func test_no_enemy_skill_equipped_previews_nothing():
    var caster := _make_caster()
    var preview := TargetPreviewComponent.of(caster)
    var near := _make_enemy(Vector2(50, 0))

    preview.update_preview(Vector2(50, 0))

    assert_null(preview.current_target())
    assert_false(HighlightComponent.of(near).is_highlighted())

func test_preview_matches_the_resolver_for_the_same_inputs():
    var skill := _enemy_skill(600.0)
    var caster := _make_caster(skill)
    var preview := TargetPreviewComponent.of(caster)
    var near := _make_enemy(Vector2(50, 0))
    var far := _make_enemy(Vector2(500, 0))

    for aim_point in [Vector2(50, 0), Vector2(500, 0), Vector2(2000, 2000)]:
        preview.update_preview(aim_point)
        var resolved := TargetSelection.find_enemy(caster, caster.global_position, aim_point, skill.targeting_range)
        assert_eq(preview.current_target(), resolved, "preview must match the resolver for aim_point %s" % aim_point)

func test_cursor_near_a_glows_a_moving_to_b_glows_b_and_unglows_a():
    var skill := _enemy_skill(600.0)
    var caster := _make_caster(skill)
    var preview := TargetPreviewComponent.of(caster)
    var a := _make_enemy(Vector2(50, 0))
    var b := _make_enemy(Vector2(-50, 0))

    preview.update_preview(Vector2(50, 0))
    assert_eq(preview.current_target(), a)
    assert_true(HighlightComponent.of(a).is_highlighted())
    assert_false(HighlightComponent.of(b).is_highlighted())

    preview.update_preview(Vector2(-50, 0))
    assert_eq(preview.current_target(), b)
    assert_false(HighlightComponent.of(a).is_highlighted(), "moving the cursor to B must unglow A")
    assert_true(HighlightComponent.of(b).is_highlighted())

func test_no_hostile_in_range_glows_nothing():
    var skill := _enemy_skill(100.0)
    var caster := _make_caster(skill)
    var preview := TargetPreviewComponent.of(caster)
    var far := _make_enemy(Vector2(5000, 0))

    preview.update_preview(Vector2(5000, 0))

    assert_null(preview.current_target())
    assert_false(HighlightComponent.of(far).is_highlighted())

func test_killing_the_glowing_target_drops_its_glow_and_moves_on_next_frame():
    var skill := _enemy_skill(600.0)
    var caster := _make_caster(skill)
    var preview := TargetPreviewComponent.of(caster)
    var dying := _make_enemy(Vector2(50, 0))
    var fallback := _make_enemy(Vector2(200, 0))

    preview.update_preview(Vector2(50, 0))
    assert_eq(preview.current_target(), dying)

    HealthComponent.of(dying).apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    preview.update_preview(Vector2(50, 0))

    assert_false(HighlightComponent.of(dying).is_highlighted(), "a dead target must lose its glow without errors")
    assert_eq(preview.current_target(), fallback)
    assert_true(HighlightComponent.of(fallback).is_highlighted())

func test_unequipping_the_last_enemy_skill_turns_the_preview_off():
    var skill := _enemy_skill(600.0)
    var caster := _make_caster(skill)
    var abilities := caster.get_node(^"AbilityComponent") as AbilityComponent
    var preview := TargetPreviewComponent.of(caster)
    var near := _make_enemy(Vector2(50, 0))

    preview.update_preview(Vector2(50, 0))
    assert_eq(preview.current_target(), near)

    abilities.unequip(2)
    preview.update_preview(Vector2(50, 0))

    assert_null(preview.current_target())
    assert_false(HighlightComponent.of(near).is_highlighted())

func test_scans_all_slots_for_the_first_enemy_targeted_skill():
    var non_enemy_skill := Skill.new()
    non_enemy_skill.targeting = Skill.Targeting.SELF
    var enemy_skill := _enemy_skill(600.0)

    var caster := _make_caster()
    var abilities := caster.get_node(^"AbilityComponent") as AbilityComponent
    var preview := TargetPreviewComponent.of(caster)
    abilities.equip(non_enemy_skill, 0)
    abilities.equip(enemy_skill, 3)
    var near := _make_enemy(Vector2(50, 0))

    preview.update_preview(Vector2(50, 0))

    assert_eq(preview.current_target(), near)
