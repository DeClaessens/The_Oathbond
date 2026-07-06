class_name CombatTextSpawner
extends Node

const FLOATING_COMBAT_TEXT := preload("res://vfx/floating_combat_text/floating_combat_text.tscn")

func _ready() -> void:
    Events.damage_dealt.connect(_on_damage_dealt)

func _on_damage_dealt(_source: Node, target: Node, amount: int, _type: StatKeys.DamageType) -> void:
    if not (target is Node2D):
        return
    var instance: FloatingCombatText = FLOATING_COMBAT_TEXT.instantiate()
    add_child(instance)
    instance.global_position = target.global_position
    instance.play(amount)
