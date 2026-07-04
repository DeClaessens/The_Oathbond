class_name Projectile
extends Area2D

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
