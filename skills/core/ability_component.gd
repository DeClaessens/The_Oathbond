class_name AbilityComponent
extends Node

signal skill_activated(index: int, skill: Skill)
signal skill_failed(index: int, reason: StringName)
signal cooldown_changed(index: int, remaining: float, total: float)
signal skill_ready(index: int)
signal slot_changed(index: int, skill: Skill)   # skill == null when emptied

const SLOT_COUNT := 4

var caster: Node
var slots: Array[AbilitySlot] = []

func _ready() -> void:
    slots.resize(SLOT_COUNT)

func equip(skill: Skill, index: int) -> void:
    assert(index >= 0 and index < SLOT_COUNT, "slot index out of range")
    var slot := AbilitySlot.new()
    slot.skill = skill
    slots[index] = slot
    slot_changed.emit(index, skill)

func unequip(index: int) -> void:
    slots[index] = null
    slot_changed.emit(index, null)

func _process(delta: float) -> void:
    for i in slots.size():
        var slot := slots[i]
        if slot != null and slot.cooldown_remaining > 0.0:
            slot.tick(delta)
            cooldown_changed.emit(i, slot.cooldown_remaining, slot.skill.cooldown)
            if slot.cooldown_remaining <= 0.0:
                skill_ready.emit(i)

func activate(index: int, aim_point: Vector2 = Vector2.ZERO) -> void:
    var slot := slots[index]
    if slot == null:
        skill_failed.emit(index, &"empty_slot")
        return

    var ctx := SkillContext.new()
    ctx.caster = caster
    ctx.caster_stats = StatsComponent.of(caster)
    if caster is Node2D:
        ctx.source_position = (caster as Node2D).global_position
    if caster != null and caster.is_inside_tree():
        ctx.spawn_parent = caster.get_tree().current_scene

    var resolved := _resolve_activation(slot.skill, slot.is_ready(), caster, ctx.source_position, aim_point)
    if not resolved.ok:
        skill_failed.emit(index, resolved.failure_reason)
        return
    ctx.targets = resolved.targets
    ctx.aim_direction = resolved.aim_direction

    for effect in slot.skill.effects:
        effect.execute(ctx)

    slot.cooldown_remaining = slot.skill.cooldown
    skill_activated.emit(index, slot.skill)

## Pure: no tree access, no side effects besides push_error on an unimplemented mode.
static func _resolve_activation(skill: Skill, is_ready: bool, caster: Node, source_position: Vector2, aim_point: Vector2) -> Dictionary:
    if not is_ready:
        return {ok = false, failure_reason = &"on_cooldown", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
    match skill.targeting:
        Skill.Targeting.SELF:
            return {ok = true, failure_reason = &"", targets = [caster] as Array[Node], aim_direction = Vector2.ZERO}
        Skill.Targeting.AREA:
            return {ok = true, failure_reason = &"", targets = [] as Array[Node], aim_direction = (aim_point - source_position).normalized()}
        Skill.Targeting.NONE:
            return {ok = true, failure_reason = &"", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
        Skill.Targeting.ENEMY, Skill.Targeting.ALLY:
            push_error("AbilityComponent: %s targeting has no target-selection system yet" % Skill.Targeting.keys()[skill.targeting])
            return {ok = false, failure_reason = &"unresolvable_targeting", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
    return {ok = false, failure_reason = &"unresolvable_targeting", targets = [] as Array[Node], aim_direction = Vector2.ZERO}
