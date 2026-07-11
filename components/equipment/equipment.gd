class_name Equipment
extends RefCounted

## The Equip Gate (decision 3): the ONE legality check for equipping `item`
## into `slot`, called by both the equip UI and load -- a second copy of this
## logic anywhere is a review failure (ADR-0015's Save Gate has the same
## shape: one function, every caller). Rules run in a fixed order and the
## list is deliberately left open for M5 (oath/material/sealed-slot) without
## adding any of that now.

static func validate(item: ItemInstance, slot: ItemTypes.EquipSlot, stats: StatsComponent) -> EquipResult:
    var def := item.definition() if item != null else null
    if def == null or not ItemTypes.accepts(slot, def.slot):
        return EquipResult.failure(&"wrong_slot")

    for attr in def.attribute_requirement:
        var required: float = float(def.attribute_requirement[attr])
        var have: float = stats.get_stat(StringName(attr)) if stats != null else 0.0
        if have < required:
            return EquipResult.failure(&"requirements_not_met")

    return EquipResult.success()
