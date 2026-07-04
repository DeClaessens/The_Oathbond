class_name StatBuffEffect
extends SkillEffect

@export var stat: StatKeys.Stat = StatKeys.Stat.MOVE_SPEED
@export var damage_type: StatKeys.DamageType = StatKeys.DamageType.PHYSICAL
@export var op: StatModifier.Op = StatModifier.Op.MULT_PCT
@export var value: float = 0.5
@export var duration: float = 5.0
@export var key: StringName = &""
@export var stack_mode: StatModifier.StackMode = StatModifier.StackMode.REFRESH

func execute(ctx: SkillContext) -> bool:
    for target in ctx.targets:
        var stats := StatsComponent.of(target)
        if stats == null:
            continue
        var mod := StatModifier.new()
        mod.stat = StatKeys.to_stringname(stat, damage_type)
        mod.op = op
        mod.value = value
        mod.duration = duration
        mod.key = key
        mod.stack_mode = stack_mode
        mod.source = self
        stats.add_modifier(mod)
    return true
