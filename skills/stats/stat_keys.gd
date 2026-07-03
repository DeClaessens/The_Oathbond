class_name StatKeys
extends RefCounted

## Typo-safe vocabulary for stat StringNames. Reference StatKeys.MOVE_SPEED,
## never a raw &"move_speed" literal — a mistyped raw string is a silent no-op
## that gear/talents/effects would hit constantly. Never instantiated.

const MOVE_SPEED    := &"move_speed"
const JUMP_VELOCITY := &"jump_velocity"     ## stored POSITIVE; applied as -value
const MAX_HEALTH    := &"max_health"
const HEALTH        := &"health"

## Damage-type-scoped keys. dmg_* = outgoing scaling, resist_* = incoming reduction.
static func dmg(type: StringName) -> StringName:
    return StringName("dmg_%s" % type)

static func resist(type: StringName) -> StringName:
    return StringName("resist_%s" % type)
