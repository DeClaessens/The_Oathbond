class_name StatBuffEffect
extends SkillEffect

## Applies a timed (or permanent) stat modifier to each target, then hands
## lifetime to the target's StatsComponent — NO await here. A speed buff and a
## jump buff are the same class, different data. Set duration <= 0 for permanent.

@export var stat: StringName = &"placeholder"
@export var op: StatModifier.Op = StatModifier.Op.MULT_PCT
@export var value: float = 0.5                                   ## +50% for MULT/ADD; absolute for FLAT
@export var duration: float = 5.0
@export var key: StringName = &""                               ## grouping tag; enables REFRESH dedup
@export var stack_mode: StatModifier.StackMode = StatModifier.StackMode.REFRESH

func execute(ctx: SkillContext) -> void:
    for target in ctx.targets:
        var stats := StatsComponent.of(target)
        if stats == null:
            push_warning("StatBuffEffect: %s has no StatsComponent" % target)
            continue
        var mod := StatModifier.new()
        mod.stat = stat
        mod.op = op
        mod.value = value
        mod.duration = duration
        mod.key = key
        mod.stack_mode = stack_mode
        mod.source = self
        stats.add_modifier(mod)
