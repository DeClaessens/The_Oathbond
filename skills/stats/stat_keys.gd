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

## --- Inspector-facing enums (authoring layer only — see handoff §13) -----
##
## These exist so designers pick a stat/damage type from a dropdown instead of
## typing a StringName by hand. The runtime (StatsComponent, StatModifier,
## get_stat/scale_outgoing/apply_damage) is untouched and still keys purely on
## StringName — to_stringname() is the only bridge between the two. Adding a
## new stat or damage type means adding one enum entry + one match arm here;
## that's what a closed enum is, not a cost to defer.

enum Stat {
    MOVE_SPEED,
    JUMP_VELOCITY,
    MAX_HEALTH,
    HEALTH,
    OUTGOING_DAMAGE,   ## compound — pair with a DamageType; resolves to dmg_<type>
    RESISTANCE,        ## compound — pair with a DamageType; resolves to resist_<type>
}

enum DamageType {
    PHYSICAL,
    FIRE,
}

## Resolve an (enum, optional damage type) pick to the StringName the runtime
## actually keys on. damage_type is ignored unless stat is OUTGOING_DAMAGE/RESISTANCE.
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
