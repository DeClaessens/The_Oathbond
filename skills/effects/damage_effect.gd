class_name DamageEffect
extends SkillEffect

@export var base_amount: int = 50
@export var damage_type: StatKeys.DamageType = StatKeys.DamageType.PHYSICAL

func execute(ctx: SkillContext) -> void:
    var type := StatKeys.damage_type_name(damage_type)
    var scaled := ctx.caster_stats.scale_outgoing(base_amount, type)
    for target in ctx.targets:
        var stats := StatsComponent.of(target)
        if stats == null:
            continue
        stats.apply_damage(scaled, type, ctx.caster)
