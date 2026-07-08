class_name FloatingCombatText
extends Node2D

const RISE_DISTANCE := 40.0
const DURATION := 0.8
const CRIT_SCALE := 1.5
const CRIT_COLOR := Color(1.0, 0.85, 0.1)

@onready var _label: Label = $Label

func play(amount: int, is_crit: bool = false) -> void:
    _label.text = str(amount)
    if is_crit:
        scale = Vector2.ONE * CRIT_SCALE
        _label.modulate = CRIT_COLOR
    var tween := create_tween()
    tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)
    tween.parallel().tween_property(_label, "modulate:a", 0.0, DURATION)
    tween.tween_callback(queue_free)
