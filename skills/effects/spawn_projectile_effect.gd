class_name SpawnProjectileEffect
extends SkillEffect

## Instantiates a projectile and launches it along ctx.aim_direction. Outgoing
## scaling is SNAPSHOT at cast time (caster's buffs bake into the projectile's
## damage), which is the standard behavior for fire-and-forget projectiles.
## Use AbilityComponent.activate_with_direction() to populate aim_direction.

@export var projectile_scene: PackedScene
@export var speed: float = 600.0
@export var base_damage: int = 50
@export var damage_type: StringName = &"fire"

func execute(ctx: SkillContext) -> void:
    if projectile_scene == null:
        push_warning("SpawnProjectileEffect: projectile_scene is null")
        return

    var scaled := float(base_damage)
    if ctx.caster_stats != null:
        scaled = ctx.caster_stats.scale_outgoing(base_damage, damage_type)

    var p := projectile_scene.instantiate() as Projectile
    p.caster      = ctx.caster
    p.direction   = ctx.aim_direction
    p.speed       = speed
    p.damage      = scaled           ## already caster-scaled
    p.damage_type = damage_type

    ctx.caster.get_tree().current_scene.add_child(p)
    p.global_position = ctx.source_position
