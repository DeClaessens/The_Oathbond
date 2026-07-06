class_name DespawnOnDeathComponent
extends Node

func _ready() -> void:
    var health := HealthComponent.of(get_parent())
    if health == null:
        push_error("DespawnOnDeathComponent: no sibling HealthComponent found on %s, despawn-on-death is disabled" % get_parent())
        return
    health.died.connect(_on_died)

func _on_died() -> void:
    get_parent().queue_free()
