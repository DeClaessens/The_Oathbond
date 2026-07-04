class_name FloatingCombatText
extends Node2D

const RISE_DISTANCE := 40.0
const DURATION := 0.8

@onready var _label: Label = $Label

func play(amount: int) -> void:
	_label.text = str(amount)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - RISE_DISTANCE, DURATION)
	tween.parallel().tween_property(_label, "modulate:a", 0.0, DURATION)
	tween.tween_callback(queue_free)
