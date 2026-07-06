class_name DespawnOnDeathComponent
extends Node

## The enemy-flavored Death response: removes the owning character from the
## tree when the sibling HealthComponent announces death. Detection stays on
## HealthComponent -- see ADR-0012.

func _ready() -> void:
    var health := HealthComponent.of(get_parent())
    if health == null:
        push_error("DespawnOnDeathComponent: no sibling HealthComponent found on %s, despawn-on-death is disabled" % get_parent())
        return
    health.died.connect(_on_died)

func _on_died() -> void:
    get_parent().queue_free()
