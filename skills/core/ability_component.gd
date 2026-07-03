class_name AbilityComponent
extends Node

## Attach to any character (player or enemy — identical code). Owns 4 equipped
## slots, ticks cooldowns, resolves the caster context, fires effects. Signals
## travel UP to whoever owns the character; this node never reaches into UI/audio.

signal skill_activated(index: int, skill: Skill)
signal skill_failed(index: int, reason: StringName)
signal cooldown_changed(index: int, remaining: float, total: float)

const SLOT_COUNT := 4

var caster: Node                    ## set by the owner character in _ready
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

## Self-targeted or explicit-target skills. `targets` is the resolved array the
## CALLER wants affected (invariant: effects never resolve their own targets).
func try_activate(index: int, targets: Array[Node], ctx: SkillContext = null) -> void:
    var slot := slots[index]
    if slot == null:
        skill_failed.emit(index, &"empty_slot")
        return
    if not slot.is_ready():
        skill_failed.emit(index, &"on_cooldown")
        return

    if ctx == null:
        ctx = SkillContext.new()
        ctx.targets = targets
    ctx.caster = caster
    ctx.caster_stats = StatsComponent.of(caster)     ## resolved ONCE, here
    if caster is Node2D:
        ctx.source_position = (caster as Node2D).global_position

    for effect in slot.skill.effects:
        effect.execute(ctx)

    slot.cooldown_remaining = slot.skill.cooldown
    skill_activated.emit(index, slot.skill)

## Directional skills (projectiles/cones/rays). Caller supplies the direction.
func activate_with_direction(index: int, direction: Vector2) -> void:
    var ctx := SkillContext.new()
    ctx.aim_direction = direction
    try_activate(index, [], ctx)
