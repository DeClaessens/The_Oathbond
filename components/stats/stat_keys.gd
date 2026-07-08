class_name StatKeys
extends RefCounted

## Typed stat StringNames — use these instead of raw literals.

const MOVE_SPEED    := &"move_speed"
const JUMP_VELOCITY := &"jump_velocity"     ## stored positive; applied as -value
const MAX_HEALTH    := &"max_health"
const MAX_MANA      := &"max_mana"
const MANA_REGEN    := &"mana_regen"

## Reserved for M2 — see docs/design/stats-and-gear.md
const HEALTH_REGEN        := &"health_regen"
const CRIT_CHANCE         := &"crit_chance"
const CRIT_MULTI          := &"crit_multi"
const COOLDOWN_REDUCTION  := &"cooldown_reduction"
const MANA_COST_REDUCTION := &"mana_cost_reduction"

## Attributes (M2.2): ordinary string-keyed stats, not `Stat` enum entries --
## like `dmg_<type>`, they compose via base + Modifiers like any other stat
## and feed derived stats through StatsComponent.DERIVATIONS (ADR-0016).
const MIGHT := &"might"
const GRACE := &"grace"
const WIT   := &"wit"

static func dmg(type: StringName) -> StringName:
    return StringName("dmg_%s" % type)

static func resist(type: StringName) -> StringName:
    return StringName("resist_%s" % type)

## Append-only — .tres files store these as ints (ADR-0005).
enum Stat {
    MOVE_SPEED,
    JUMP_VELOCITY,
    MAX_HEALTH,
    OUTGOING_DAMAGE,
    RESISTANCE,
    MAX_MANA,
    MANA_REGEN,
    HEALTH_REGEN,
    CRIT_CHANCE,
    CRIT_MULTI,
    COOLDOWN_REDUCTION,
    MANA_COST_REDUCTION,
}

## Append-only — .tres files store these as ints (ADR-0005).
enum DamageType {
    PHYSICAL,
    EMBER,
    RADIANCE,
    ROT,
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
        Stat.HEALTH_REGEN: return HEALTH_REGEN
        Stat.CRIT_CHANCE: return CRIT_CHANCE
        Stat.CRIT_MULTI: return CRIT_MULTI
        Stat.COOLDOWN_REDUCTION: return COOLDOWN_REDUCTION
        Stat.MANA_COST_REDUCTION: return MANA_COST_REDUCTION
    return &""

static func damage_type_name(type: DamageType) -> StringName:
    match type:
        DamageType.PHYSICAL: return &"physical"
        DamageType.EMBER:    return &"ember"
        DamageType.RADIANCE: return &"radiance"
        DamageType.ROT:      return &"rot"
    return &"physical"
