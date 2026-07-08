class_name DamagePacket
extends RefCounted

## The outgoing-damage seam's return value (ADR-0017): a scaled amount plus
## the caster-level crit flag, replacing the bare float `scale_outgoing` used
## to return. Built once per hit by `StatsComponent.roll_outgoing`.

var amount: float
var type: StatKeys.DamageType
var is_crit: bool

func _init(p_amount: float, p_type: StatKeys.DamageType, p_is_crit: bool) -> void:
    amount = p_amount
    type = p_type
    is_crit = p_is_crit
