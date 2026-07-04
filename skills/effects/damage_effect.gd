class_name DamageEffect
extends SkillEffect

@export var base_amount: int = 50
@export var damage_type: StatKeys.DamageType = StatKeys.DamageType.PHYSICAL

func execute(ctx: SkillContext) -> void:
    var scaled := ctx.caster_stats.scale_outgoing(base_amount, damage_type)
    for target in ctx.targets:
        var health := HealthComponent.of(target)
        if health == null:
            continue
        health.apply_damage(scaled, damage_type, ctx.caster)
