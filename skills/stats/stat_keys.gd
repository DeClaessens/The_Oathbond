class_name StatKeys
extends RefCounted

## Typed stat StringNames — use these instead of raw literals.

const MOVE_SPEED    := &"move_speed"
const JUMP_VELOCITY := &"jump_velocity"     ## stored positive; applied as -value
const MAX_HEALTH    := &"max_health"
const HEALTH        := &"health"

static func dmg(type: StringName) -> StringName:
    return StringName("dmg_%s" % type)

static func resist(type: StringName) -> StringName:
    return StringName("resist_%s" % type)

enum Stat {
    MOVE_SPEED,
    JUMP_VELOCITY,
    MAX_HEALTH,
    HEALTH,
    OUTGOING_DAMAGE,
    RESISTANCE,
}

enum DamageType {
    PHYSICAL,
    FIRE,
}

static func to_stringname(stat: Stat, damage_type: DamageType = DamageType.PHYSICAL) -> StringName:
    match stat:
        Stat.MOVE_SPEED:      return MOVE_SPEED
        Stat.JUMP_VELOCITY:   return JUMP_VELOCITY
        Stat.MAX_HEALTH:      return MAX_HEALTH
        Stat.HEALTH:          return HEALTH
        Stat.OUTGOING_DAMAGE: return dmg(damage_type_name(damage_type))
        Stat.RESISTANCE:      return resist(damage_type_name(damage_type))
    return &""

static func damage_type_name(type: DamageType) -> StringName:
    match type:
        DamageType.PHYSICAL: return &"physical"
        DamageType.FIRE:     return &"fire"
    return &"physical"
