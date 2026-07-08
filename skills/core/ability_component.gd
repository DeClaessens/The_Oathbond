class_name AbilityComponent
extends Node

signal skill_activated(index: int, skill: Skill)
signal skill_failed(index: int, reason: StringName)
signal cooldown_changed(index: int, remaining: float, total: float)
signal skill_ready(index: int)
signal slot_changed(index: int, skill: Skill)
signal global_cooldown_started(duration: float)

const SLOT_COUNT := 4
const CDR_CAP := 0.75
const MCR_CAP := 0.75

@export var global_cooldown: float = 0.5

var caster: Node
var slots: Array[AbilitySlot] = []
var _gcd_remaining: float = 0.0

func _ready() -> void:
    slots.resize(SLOT_COUNT)

static func _is_valid_slot(index: int) -> bool:
    return index >= 0 and index < SLOT_COUNT

func equip(skill: Skill, index: int) -> void:
    if not _is_valid_slot(index):
        push_error("AbilityComponent.equip: slot index %d out of range" % index)
        return
    var slot := AbilitySlot.new()
    slot.skill = skill
    slots[index] = slot
    slot_changed.emit(index, skill)

func unequip(index: int) -> void:
    if not _is_valid_slot(index):
        push_error("AbilityComponent.unequip: slot index %d out of range" % index)
        return
    slots[index] = null
    slot_changed.emit(index, null)

func _process(delta: float) -> void:
    if _gcd_remaining > 0.0:
        _gcd_remaining = maxf(0.0, _gcd_remaining - delta)
    for i in slots.size():
        var slot := slots[i]
        if slot != null and slot.cooldown_remaining > 0.0:
            slot.tick(delta)
            cooldown_changed.emit(i, slot.cooldown_remaining, slot.skill.cooldown)
            if slot.cooldown_remaining <= 0.0:
                skill_ready.emit(i)

func activate(index: int, aim_point: Vector2 = Vector2.ZERO) -> void:
    if not _is_valid_slot(index):
        skill_failed.emit(index, &"invalid_slot")
        return
    var slot := slots[index]
    if slot == null:
        skill_failed.emit(index, &"empty_slot")
        return

    var caster_stats := StatsComponent.of(caster)
    var mcr := 0.0 if caster_stats == null else clampf(caster_stats.get_stat(StatKeys.MANA_COST_REDUCTION), 0.0, MCR_CAP)
    var effective_mana_cost := slot.skill.mana_cost * (1.0 - mcr)

    var mana := ManaComponent.of(caster)
    var has_enough_mana := mana == null or mana.can_afford(effective_mana_cost)

    var ctx := SkillContext.new()
    ctx.caster = caster
    ctx.caster_stats = caster_stats
    if caster is Node2D:
        ctx.source_position = (caster as Node2D).global_position
    if caster != null and caster.is_inside_tree():
        ctx.spawn_parent = caster.get_tree().current_scene

    var gcd_ready := _gcd_remaining <= 0.0
    var resolved := _resolve_activation(slot.skill, gcd_ready, slot.is_ready(), has_enough_mana, caster, ctx.source_position, aim_point)
    if not resolved.ok:
        skill_failed.emit(index, resolved.failure_reason)
        return
    ctx.targets = resolved.targets
    ctx.aim_direction = resolved.aim_direction

    for effect in slot.skill.effects:
        if not effect.execute(ctx):
            skill_failed.emit(index, &"effect_failed")
            return

    var cdr := 0.0 if caster_stats == null else clampf(caster_stats.get_stat(StatKeys.COOLDOWN_REDUCTION), 0.0, CDR_CAP)
    slot.cooldown_remaining = slot.skill.cooldown * (1.0 - cdr)
    if mana != null:
        mana.spend(effective_mana_cost)
    if not slot.skill.ignores_global_cooldown:
        _gcd_remaining = global_cooldown
        global_cooldown_started.emit(global_cooldown)
    skill_activated.emit(index, slot.skill)

static func _resolve_activation(skill: Skill, gcd_ready: bool, is_ready: bool, has_enough_mana: bool, caster: Node, source_position: Vector2, aim_point: Vector2) -> Dictionary:
    if not skill.ignores_global_cooldown and not gcd_ready:
        return {ok = false, failure_reason = &"on_global_cooldown", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
    if not is_ready:
        return {ok = false, failure_reason = &"on_cooldown", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
    if not has_enough_mana:
        return {ok = false, failure_reason = &"insufficient_mana", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
    match skill.targeting:
        Skill.Targeting.SELF:
            return {ok = true, failure_reason = &"", targets = [caster] as Array[Node], aim_direction = Vector2.ZERO}
        Skill.Targeting.AREA:
            return {ok = true, failure_reason = &"", targets = [] as Array[Node], aim_direction = (aim_point - source_position).normalized()}
        Skill.Targeting.NONE:
            return {ok = true, failure_reason = &"", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
        Skill.Targeting.ENEMY:
            var enemy := TargetSelection.find_enemy(caster, source_position, aim_point, skill.targeting_range)
            if enemy == null:
                return {ok = false, failure_reason = &"no_target", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
            var enemy_position := (enemy as Node2D).global_position if enemy is Node2D else source_position
            return {ok = true, failure_reason = &"", targets = [enemy] as Array[Node], aim_direction = (enemy_position - source_position).normalized()}
        Skill.Targeting.ALLY:
            var ally := TargetSelection.find_ally(caster, source_position, aim_point, skill.targeting_range)
            if ally == null:
                return {ok = false, failure_reason = &"no_target", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
            var ally_position := (ally as Node2D).global_position if ally is Node2D else source_position
            return {ok = true, failure_reason = &"", targets = [ally] as Array[Node], aim_direction = (ally_position - source_position).normalized()}
    return {ok = false, failure_reason = &"unresolvable_targeting", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
