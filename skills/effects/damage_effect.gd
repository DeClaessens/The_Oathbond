class_name DamageEffect
extends SkillEffect

## Instantly damages every target. Scales the base by the CASTER's offensive
## stats (single seam) at cast time, then lets each target's StatsComponent apply
## resistance and emit the event. This effect never emits damage events itself.

@export var base_amount: int = 50
@export var damage_type: StatKeys.DamageType = StatKeys.DamageType.PHYSICAL

func execute(ctx: SkillContext) -> void:
    var type := StatKeys.damage_type_name(damage_type)
    var scaled := float(base_amount)
    if ctx.caster_stats != null:
        scaled = ctx.caster_stats.scale_outgoing(base_amount, type)
    for target in ctx.targets:
        var stats := StatsComponent.of(target)
        if stats == null:
            continue
        stats.apply_damage(scaled, type, ctx.caster)
