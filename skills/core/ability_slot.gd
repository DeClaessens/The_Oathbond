class_name AbilitySlot
extends RefCounted

## Runtime wrapper around one equipped Skill. Cooldown lives HERE, not on the
## Skill resource, so two characters sharing a Skill.tres have independent
## cooldowns.

var skill: Skill
var cooldown_remaining: float = 0.0

func is_ready() -> bool:
    return cooldown_remaining <= 0.0

func tick(delta: float) -> void:
    cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
