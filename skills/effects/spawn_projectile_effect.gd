class_name SpawnProjectileEffect
extends SkillEffect

@export var projectile_scene: PackedScene
@export var speed: float = 600.0
@export var base_damage: int = 50
@export var damage_type: StatKeys.DamageType = StatKeys.DamageType.EMBER

func execute(ctx: SkillContext) -> bool:
    if projectile_scene == null:
        push_error("SpawnProjectileEffect: projectile_scene is not assigned")
        return false
    if ctx.spawn_parent == null:
        push_error("SpawnProjectileEffect: ctx.spawn_parent is null, caster is not in a tree")
        return false
    if ctx.caster_stats == null:
        push_error("SpawnProjectileEffect: ctx.caster_stats is null, caster has no StatsComponent")
        return false

    var scaled := ctx.caster_stats.scale_outgoing(base_damage, damage_type)

    var p := projectile_scene.instantiate() as Projectile
    p.caster = ctx.caster
    p.direction = ctx.aim_direction
    p.speed = speed
    p.damage = scaled
    p.damage_type = damage_type

    ctx.spawn_parent.add_child(p)
    p.global_position = ctx.source_position
    return true
