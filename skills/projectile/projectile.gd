class_name Projectile
extends Area2D

## Self-contained projectile. Moves in a direction, damages the first valid
## StatsComponent-bearing body it overlaps, frees itself. Also self-frees after
## `lifetime` seconds (safety net for off-screen misses — with no enemies yet it
## simply flies and expires, which is correct).
##
## `damage` arrives ALREADY caster-scaled from SpawnProjectileEffect; the target
## still applies resistance in apply_damage.
##
## Scene setup (see §6.2): CollisionShape2D, collision_layer = PlayerProjectile,
## collision_mask = World | Enemy, body_entered -> _on_body_entered.

var caster: Node
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: float = 50.0
var damage_type: StringName = &"physical"

@export var lifetime: float = 3.0

func _ready() -> void:
    get_tree().create_timer(lifetime).timeout.connect(queue_free)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
    if body == caster:
        return
    var stats := StatsComponent.of(body)
    if stats != null:
        stats.apply_damage(damage, damage_type, caster)
    queue_free()
