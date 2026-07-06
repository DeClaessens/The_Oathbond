class_name StatKeys
extends RefCounted

## Typed stat StringNames — use these instead of raw literals.

const MOVE_SPEED    := &"move_speed"
const JUMP_VELOCITY := &"jump_velocity"     ## stored positive; applied as -value
const MAX_HEALTH    := &"max_health"
const MAX_MANA      := &"max_mana"
const MANA_REGEN    := &"mana_regen"

static func dmg(type: StringName) -> StringName:
    return StringName("dmg_%s" % type)

static func resist(type: StringName) -> StringName:
    return StringName("resist_%s" % type)

enum Stat {
    MOVE_SPEED,
    JUMP_VELOCITY,
    MAX_HEALTH,
    OUTGOING_DAMAGE,
    RESISTANCE,
    MAX_MANA,
    MANA_REGEN,
}

enum DamageType {
    PHYSICAL,
    FIRE,
}

## damage_type is only read for OUTGOING_DAMAGE and RESISTANCE; it's ignored
## for MOVE_SPEED, JUMP_VELOCITY, MAX_HEALTH, MAX_MANA, and MANA_REGEN. No
## default — always pass the DamageType you mean, even when the Stat won't
## use it.
static func to_stringname(stat: Stat, damage_type: DamageType) -> StringName:
    match stat:
        Stat.MOVE_SPEED:      return MOVE_SPEED
        Stat.JUMP_VELOCITY:   return JUMP_VELOCITY
        Stat.MAX_HEALTH:      return MAX_HEALTH
        Stat.OUTGOING_DAMAGE: return dmg(damage_type_name(damage_type))
        Stat.RESISTANCE:      return resist(damage_type_name(damage_type))
        Stat.MAX_MANA:        return MAX_MANA
        Stat.MANA_REGEN:      return MANA_REGEN
    return &""

static func damage_type_name(type: DamageType) -> StringName:
    match type:
        DamageType.PHYSICAL: return &"physical"
        DamageType.FIRE:     return &"fire"
    return &"physical"
