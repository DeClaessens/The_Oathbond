class_name AbilityComponent
extends Node

signal skill_activated(index: int, skill: Skill)
signal skill_failed(index: int, reason: StringName)
signal cooldown_changed(index: int, remaining: float, total: float)

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

func unequip(index: int) -> void:
    slots[index] = null

func _process(delta: float) -> void:
    for i in slots.size():
        var slot := slots[i]
        if slot != null and slot.cooldown_remaining > 0.0:
            slot.tick(delta)
            cooldown_changed.emit(i, slot.cooldown_remaining, slot.skill.cooldown)

func activate(index: int, targets: Array[Node] = [], direction: Vector2 = Vector2.ZERO) -> void:
    var slot := slots[index]
    if slot == null:
        skill_failed.emit(index, &"empty_slot")
        return
    if not slot.is_ready():
        skill_failed.emit(index, &"on_cooldown")
        return

    var ctx := SkillContext.new()
    ctx.targets = targets
    ctx.aim_direction = direction
    ctx.caster = caster
    ctx.caster_stats = StatsComponent.of(caster)
    if caster is Node2D:
        ctx.source_position = (caster as Node2D).global_position

    for effect in slot.skill.effects:
        effect.execute(ctx)

    slot.cooldown_remaining = slot.skill.cooldown
    skill_activated.emit(index, slot.skill)
