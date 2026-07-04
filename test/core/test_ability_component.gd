extends GutTest

var caster: Node

func before_each():
    caster = Node.new()

func after_each():
    caster.free()

func test_self_targeting_targets_the_caster():
    var result := AbilityComponent._resolve_targeting(Skill.Targeting.SELF, caster, Vector2.ZERO, Vector2.ZERO)
    assert_true(result.ok)
    assert_eq(result.targets, [caster] as Array[Node])

func test_area_targeting_derives_direction_from_aim_point():
    var result := AbilityComponent._resolve_targeting(Skill.Targeting.AREA, caster, Vector2.ZERO, Vector2(10, 0))
    assert_true(result.ok)
    assert_eq(result.targets, [] as Array[Node])
    assert_eq(result.aim_direction, Vector2.RIGHT)

func test_none_targeting_resolves_to_nothing():
    var result := AbilityComponent._resolve_targeting(Skill.Targeting.NONE, caster, Vector2.ZERO, Vector2(5, 5))
    assert_true(result.ok)
    assert_eq(result.targets, [] as Array[Node])
    assert_eq(result.aim_direction, Vector2.ZERO)

func test_enemy_targeting_fails_with_no_target_selection_system():
    var result := AbilityComponent._resolve_targeting(Skill.Targeting.ENEMY, caster, Vector2.ZERO, Vector2.ZERO)
    assert_false(result.ok)
    assert_push_error("ENEMY")

func test_ally_targeting_fails_with_no_target_selection_system():
    var result := AbilityComponent._resolve_targeting(Skill.Targeting.ALLY, caster, Vector2.ZERO, Vector2.ZERO)
    assert_false(result.ok)
    assert_push_error("ALLY")

func test_equip_emits_slot_changed_with_the_skill():
    var abilities := AbilityComponent.new()
    add_child_autofree(abilities)
    var skill := Skill.new()
    watch_signals(abilities)
    abilities.equip(skill, 2)
    assert_signal_emitted_with_parameters(abilities, "slot_changed", [2, skill])

func test_unequip_emits_slot_changed_with_null():
    var abilities := AbilityComponent.new()
    add_child_autofree(abilities)
    abilities.equip(Skill.new(), 0)
    watch_signals(abilities)
    abilities.unequip(0)
    assert_signal_emitted_with_parameters(abilities, "slot_changed", [0, null])
