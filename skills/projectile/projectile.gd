class_name Projectile
extends Area2D

var caster: Node
var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: float = 50.0
var damage_type: StatKeys.DamageType = StatKeys.DamageType.PHYSICAL
var is_crit: bool = false

@export var lifetime: float = 3.0

func _ready() -> void:
    get_tree().create_timer(lifetime).timeout.connect(queue_free)
    queue_redraw()

func _draw() -> void:
    draw_circle(Vector2.ZERO, 8.0, Color.ORANGE_RED)

func _physics_process(delta: float) -> void:
    position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
    if body == caster:
        return
    var health := HealthComponent.of(body)
    if health != null:
        health.apply_damage(damage, damage_type, caster, is_crit)
    queue_free()
