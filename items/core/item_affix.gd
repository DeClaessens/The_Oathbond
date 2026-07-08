class_name ItemAffix
extends RefCounted

## One rolled stat modifier on an ItemInstance: runtime/save data only
## (ADR-0003), never a Resource. On equip (M2.4) each becomes a StatModifier.
## Implicit mods authored on a definition use AffixEntry instead (a Resource);
## the two are read uniformly via triple().

var stat: StringName = &""
var op: StatModifier.Op = StatModifier.Op.FLAT
var value: float = 0.0

func _init(p_stat: StringName = &"", p_op: StatModifier.Op = StatModifier.Op.FLAT, p_value: float = 0.0) -> void:
    stat = p_stat
    op = p_op
    value = p_value

## Reads a {stat, op, value} triple from either an authored AffixEntry (fixed
## value = min_value) or a rolled ItemAffix -- the one seam M2.4's equip path
## iterates implicit mods and rolled affixes through uniformly.
static func triple(source: Object) -> Dictionary:
    if source is AffixEntry:
        return {"stat": source.stat, "op": source.op, "value": source.min_value}
    if source is ItemAffix:
        return {"stat": source.stat, "op": source.op, "value": source.value}
    push_error("ItemAffix.triple: unsupported source %s" % source)
    return {}
