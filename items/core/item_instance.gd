class_name ItemInstance
extends RefCounted

## A rolled drop: definition id + rarity + rolled affixes. Runtime/save data
## only (ADR-0003) -- NEVER a Resource, never persisted as a .tres. Resolves
## its definition through the ItemCatalog; never mutates one. Persists as a
## plain dict through the single Save Gate (ADR-0015).

var definition_id: StringName = &""
var rarity: ItemTypes.Rarity = ItemTypes.Rarity.COMMON
var rolled_affixes: Array[ItemAffix] = []

func definition() -> ItemDefinition:
    return ItemCatalog.by_id(definition_id)

## Character-file shape: {def_id, rarity, affixes:[{stat, op, value}]}.
func to_dict() -> Dictionary:
    var affixes: Array = []
    for affix in rolled_affixes:
        affixes.append({"stat": String(affix.stat), "op": int(affix.op), "value": affix.value})
    return {"def_id": String(definition_id), "rarity": int(rarity), "affixes": affixes}

## Rebuilds an instance from a section entry already sanitized by the Save
## Gate, so it trusts the shape (validation is never done twice, ADR-0015).
static func from_dict(data: Dictionary) -> ItemInstance:
    var inst := ItemInstance.new()
    inst.definition_id = StringName(data.get("def_id", ""))
    inst.rarity = int(data.get("rarity", ItemTypes.Rarity.COMMON)) as ItemTypes.Rarity
    for a in data.get("affixes", []):
        inst.rolled_affixes.append(ItemAffix.new(
            StringName(a.get("stat", "")),
            int(a.get("op", StatModifier.Op.FLAT)) as StatModifier.Op,
            float(a.get("value", 0.0)),
        ))
    return inst
