class_name AbilitySlot
extends RefCounted

var skill: Skill
var cooldown_remaining: float = 0.0

func is_ready() -> bool:
    return cooldown_remaining <= 0.0

func tick(delta: float) -> void:
    cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
