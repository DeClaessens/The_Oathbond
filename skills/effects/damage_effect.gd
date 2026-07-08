class_name DamageEffect
extends SkillEffect

@export var base_amount: int = 50
@export var damage_type: StatKeys.DamageType = StatKeys.DamageType.PHYSICAL

func execute(ctx: SkillContext) -> bool:
    if ctx.caster_stats == null:
        push_error("DamageEffect: ctx.caster_stats is null, caster has no StatsComponent")
        return false
    var packet := ctx.caster_stats.roll_outgoing(base_amount, damage_type)
    for target in ctx.targets:
        var health := HealthComponent.of(target)
        if health == null:
            continue
        health.apply_damage(packet.amount, packet.type, ctx.caster, packet.is_crit)
    return true
