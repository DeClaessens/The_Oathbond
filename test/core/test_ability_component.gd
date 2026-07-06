extends GutTest

class FakeSkillEffect extends SkillEffect:
    var execute_calls := 0
    var last_ctx: SkillContext
    var succeeds := true

    func execute(ctx: SkillContext) -> bool:
        execute_calls += 1
        last_ctx = ctx
        return succeeds


var caster: Node

func before_each():
    caster = Node.new()

func after_each():
    caster.free()

func _skill_with_targeting(targeting: Skill.Targeting) -> Skill:
    var skill := Skill.new()
    skill.targeting = targeting
    return skill

func test_self_targeting_targets_the_caster():
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    var result := AbilityComponent._resolve_activation(skill, true, true, caster, Vector2.ZERO, Vector2.ZERO)
    assert_true(result.ok)
    assert_eq(result.targets, [caster] as Array[Node])

func test_area_targeting_derives_direction_from_aim_point():
    var skill := _skill_with_targeting(Skill.Targeting.AREA)
    var result := AbilityComponent._resolve_activation(skill, true, true, caster, Vector2.ZERO, Vector2(10, 0))
    assert_true(result.ok)
    assert_eq(result.targets, [] as Array[Node])
    assert_eq(result.aim_direction, Vector2.RIGHT)

func test_none_targeting_resolves_to_nothing():
    var skill := _skill_with_targeting(Skill.Targeting.NONE)
    var result := AbilityComponent._resolve_activation(skill, true, true, caster, Vector2.ZERO, Vector2(5, 5))
    assert_true(result.ok)
    assert_eq(result.targets, [] as Array[Node])
    assert_eq(result.aim_direction, Vector2.ZERO)

func test_enemy_targeting_fails_with_no_target_selection_system():
    var skill := _skill_with_targeting(Skill.Targeting.ENEMY)
    var result := AbilityComponent._resolve_activation(skill, true, true, caster, Vector2.ZERO, Vector2.ZERO)
    assert_false(result.ok)
    assert_eq(result.failure_reason, &"unresolvable_targeting")
    assert_push_error("ENEMY")

func test_ally_targeting_fails_with_no_target_selection_system():
    var skill := _skill_with_targeting(Skill.Targeting.ALLY)
    var result := AbilityComponent._resolve_activation(skill, true, true, caster, Vector2.ZERO, Vector2.ZERO)
    assert_false(result.ok)
    assert_eq(result.failure_reason, &"unresolvable_targeting")
    assert_push_error("ALLY")

func test_on_cooldown_fails_before_targeting_is_considered():
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    var result := AbilityComponent._resolve_activation(skill, false, true, caster, Vector2.ZERO, Vector2.ZERO)
    assert_false(result.ok)
    assert_eq(result.failure_reason, &"on_cooldown")

func test_insufficient_mana_fails_before_targeting_is_considered():
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    var result := AbilityComponent._resolve_activation(skill, true, false, caster, Vector2.ZERO, Vector2.ZERO)
    assert_false(result.ok)
    assert_eq(result.failure_reason, &"insufficient_mana")

func test_on_cooldown_takes_priority_over_insufficient_mana():
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    var result := AbilityComponent._resolve_activation(skill, false, false, caster, Vector2.ZERO, Vector2.ZERO)
    assert_eq(result.failure_reason, &"on_cooldown")

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

func test_activate_runs_effects_sets_cooldown_and_emits_skill_activated():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.cooldown = 2.5
    var effect := FakeSkillEffect.new()
    skill.effects = [effect] as Array[SkillEffect]
    abilities.equip(skill, 0)

    watch_signals(abilities)
    abilities.activate(0)

    assert_eq(effect.execute_calls, 1)
    assert_eq(effect.last_ctx.targets, [caster] as Array[Node])
    assert_eq(abilities.slots[0].cooldown_remaining, 2.5)
    assert_signal_emitted_with_parameters(abilities, "skill_activated", [0, skill])

func test_activate_on_empty_slot_fails_without_running_effects():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)

    watch_signals(abilities)
    abilities.activate(0)

    assert_signal_emitted_with_parameters(abilities, "skill_failed", [0, &"empty_slot"])

func test_activate_on_cooldown_fails_without_running_effects():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    var effect := FakeSkillEffect.new()
    skill.effects = [effect] as Array[SkillEffect]
    abilities.equip(skill, 0)
    abilities.slots[0].cooldown_remaining = 1.0

    watch_signals(abilities)
    abilities.activate(0)

    assert_eq(effect.execute_calls, 0)
    assert_signal_emitted_with_parameters(abilities, "skill_failed", [0, &"on_cooldown"])

func test_equip_with_negative_index_is_a_safe_no_op():
    var abilities := AbilityComponent.new()
    add_child_autofree(abilities)
    abilities.equip(Skill.new(), -1)
    assert_push_error("out of range")

func test_equip_with_index_at_slot_count_is_a_safe_no_op():
    var abilities := AbilityComponent.new()
    add_child_autofree(abilities)
    abilities.equip(Skill.new(), AbilityComponent.SLOT_COUNT)
    assert_push_error("out of range")

func test_unequip_with_invalid_index_is_a_safe_no_op():
    var abilities := AbilityComponent.new()
    add_child_autofree(abilities)
    abilities.unequip(-1)
    assert_push_error("out of range")

func test_activate_with_negative_index_fails_with_invalid_slot():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)

    watch_signals(abilities)
    abilities.activate(-1)

    assert_signal_emitted_with_parameters(abilities, "skill_failed", [-1, &"invalid_slot"])

func test_activate_with_index_at_slot_count_fails_with_invalid_slot():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)

    watch_signals(abilities)
    abilities.activate(AbilityComponent.SLOT_COUNT)

    assert_signal_emitted_with_parameters(abilities, "skill_failed", [AbilityComponent.SLOT_COUNT, &"invalid_slot"])

func test_activate_with_failing_effect_fails_without_setting_cooldown():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.cooldown = 2.5
    var effect := FakeSkillEffect.new()
    effect.succeeds = false
    skill.effects = [effect] as Array[SkillEffect]
    abilities.equip(skill, 0)

    watch_signals(abilities)
    abilities.activate(0)

    assert_eq(abilities.slots[0].cooldown_remaining, 0.0, "cooldown must not be consumed on effect failure")
    assert_signal_emitted_with_parameters(abilities, "skill_failed", [0, &"effect_failed"])
    assert_signal_not_emitted(abilities, "skill_activated")

func test_activate_stops_running_effects_after_one_fails():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    var failing := FakeSkillEffect.new()
    failing.succeeds = false
    var trailing := FakeSkillEffect.new()
    skill.effects = [failing, trailing] as Array[SkillEffect]
    abilities.equip(skill, 0)

    abilities.activate(0)

    assert_eq(trailing.execute_calls, 0, "effects after a failure must not run")

func test_activate_with_unassigned_projectile_scene_does_not_consume_cooldown():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster.add_child(caster_stats)

    var skill := _skill_with_targeting(Skill.Targeting.AREA)
    skill.cooldown = 1.0
    var spawn_effect := SpawnProjectileEffect.new()  # projectile_scene left unassigned
    skill.effects = [spawn_effect] as Array[SkillEffect]
    abilities.equip(skill, 0)

    watch_signals(abilities)
    abilities.activate(0)

    assert_eq(abilities.slots[0].cooldown_remaining, 0.0)
    assert_signal_emitted_with_parameters(abilities, "skill_failed", [0, &"effect_failed"])
    assert_signal_not_emitted(abilities, "skill_activated")
    assert_push_error("projectile_scene")

func test_activate_with_no_mana_component_casts_for_free():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.mana_cost = 9999.0
    var effect := FakeSkillEffect.new()
    skill.effects = [effect] as Array[SkillEffect]
    abilities.equip(skill, 0)

    watch_signals(abilities)
    abilities.activate(0)

    assert_eq(effect.execute_calls, 1)
    assert_signal_emitted(abilities, "skill_activated")

func test_activate_fails_and_does_not_run_effects_when_mana_is_insufficient():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster_stats.base_stats = {StatKeys.MAX_MANA: 10.0}
    caster.add_child(caster_stats)
    caster.add_child(mana)
    add_child_autofree(caster)

    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.mana_cost = 20.0
    var effect := FakeSkillEffect.new()
    skill.effects = [effect] as Array[SkillEffect]
    abilities.equip(skill, 0)

    watch_signals(abilities)
    abilities.activate(0)

    assert_eq(effect.execute_calls, 0)
    assert_signal_emitted_with_parameters(abilities, "skill_failed", [0, &"insufficient_mana"])

func test_activate_debits_mana_only_after_effects_succeed():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster_stats.base_stats = {StatKeys.MAX_MANA: 100.0}
    caster.add_child(caster_stats)
    caster.add_child(mana)
    add_child_autofree(caster)

    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.mana_cost = 30.0
    var failing := FakeSkillEffect.new()
    failing.succeeds = false
    skill.effects = [failing] as Array[SkillEffect]
    abilities.equip(skill, 0)

    abilities.activate(0)

    assert_eq(mana.current(), 100.0, "mana must not be spent when a cast fails")

func test_activate_debits_mana_on_successful_cast():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    var caster_stats := StatsComponent.new()
    caster_stats.name = "StatsComponent"
    caster_stats.base_stats = {StatKeys.MAX_MANA: 100.0}
    caster.add_child(caster_stats)
    caster.add_child(mana)
    add_child_autofree(caster)

    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    skill.mana_cost = 30.0
    var effect := FakeSkillEffect.new()
    skill.effects = [effect] as Array[SkillEffect]
    abilities.equip(skill, 0)

    abilities.activate(0)

    assert_eq(mana.current(), 70.0)

func test_process_emits_skill_ready_once_cooldown_reaches_zero():
    var abilities := AbilityComponent.new()
    abilities.caster = caster
    add_child_autofree(abilities)
    add_child_autofree(caster)
    var skill := _skill_with_targeting(Skill.Targeting.SELF)
    abilities.equip(skill, 0)
    abilities.slots[0].cooldown_remaining = 0.4

    watch_signals(abilities)
    abilities._process(0.5)

    assert_signal_emitted_with_parameters(abilities, "cooldown_changed", [0, 0.0, skill.cooldown])
    assert_signal_emitted_with_parameters(abilities, "skill_ready", [0])
    assert_signal_emit_count(abilities, "skill_ready", 1)

    abilities._process(0.5)

    assert_signal_emit_count(abilities, "skill_ready", 1, "skill_ready does not re-fire while already ready")
