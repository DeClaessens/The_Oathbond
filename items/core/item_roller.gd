class_name ItemRoller
extends RefCounted

## Rolls an ItemInstance from an ItemDefinition (decision 5): picks rarity by
## weight, picks the affix count for that rarity, draws that many *distinct*
## entries from the definition's affix_pool, and rolls each value uniformly in
## [min, max]. Uses randf/randi; never writes to a Resource or the catalog.

## Rarity roll weights (tunable, decision 2). HEIRLOOM is authored, never
## rolled, so it carries no weight.
const RARITY_WEIGHTS := {
    ItemTypes.Rarity.COMMON: 60,
    ItemTypes.Rarity.QUALITY: 30,
    ItemTypes.Rarity.MASTERWORK: 10,
}

## Affix count range [min, max] per rolled rarity (decision 2).
const AFFIX_COUNTS := {
    ItemTypes.Rarity.COMMON: [0, 0],
    ItemTypes.Rarity.QUALITY: [1, 2],
    ItemTypes.Rarity.MASTERWORK: [3, 5],
}

## `level` is threaded but unused at M2 (zone tiers are M4) -- accepted and
## ignored so the signature is stable.
static func roll(definition: ItemDefinition, _level: int = 1) -> ItemInstance:
    var inst := ItemInstance.new()
    if definition == null:
        push_error("ItemRoller.roll: null definition")
        return inst
    inst.definition_id = definition.id
    inst.rarity = _roll_rarity()
    inst.rolled_affixes = _roll_affixes(definition.affix_pool, _roll_affix_count(inst.rarity))
    return inst

static func _roll_rarity() -> ItemTypes.Rarity:
    var total := 0
    for weight in RARITY_WEIGHTS.values():
        total += weight
    var pick := randi() % total
    var acc := 0
    for rarity in RARITY_WEIGHTS:
        acc += RARITY_WEIGHTS[rarity]
        if pick < acc:
            return rarity
    return ItemTypes.Rarity.COMMON

static func _roll_affix_count(rarity: ItemTypes.Rarity) -> int:
    var span: Array = AFFIX_COUNTS.get(rarity, [0, 0])
    var lo: int = span[0]
    var hi: int = span[1]
    if hi <= lo:
        return lo
    return lo + randi() % (hi - lo + 1)

static func _roll_affixes(pool: AffixPool, count: int) -> Array[ItemAffix]:
    var out: Array[ItemAffix] = []
    if pool == null or count <= 0:
        return out
    var available: Array = pool.entries.duplicate()
    var draws := mini(count, available.size())
    for i in draws:
        var idx := randi() % available.size()
        var entry: AffixEntry = available[idx]
        available.remove_at(idx)
        out.append(_roll_entry(entry))
    return out

static func _roll_entry(entry: AffixEntry) -> ItemAffix:
    var value := entry.min_value
    if entry.max_value > entry.min_value:
        value = entry.min_value + randf() * (entry.max_value - entry.min_value)
    return ItemAffix.new(entry.stat, entry.op, value)
