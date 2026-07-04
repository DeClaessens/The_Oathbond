class_name SpawnProjectileEffect
extends SkillEffect

@export var projectile_scene: PackedScene
@export var speed: float = 600.0
@export var base_damage: int = 50
@export var damage_type: StatKeys.DamageType = StatKeys.DamageType.FIRE

func execute(ctx: SkillContext) -> void:
    if projectile_scene == null:
        return

    var type := StatKeys.damage_type_name(damage_type)
    var scaled := ctx.caster_stats.scale_outgoing(base_damage, type)

    var p := projectile_scene.instantiate() as Projectile
    p.caster = ctx.caster
    p.direction = ctx.aim_direction
    p.speed = speed
    p.damage = scaled
    p.damage_type = type

    ctx.caster.get_tree().current_scene.add_child(p)
    p.global_position = ctx.source_position
