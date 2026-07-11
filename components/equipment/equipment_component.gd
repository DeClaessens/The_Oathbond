class_name EquipmentComponent
extends Node

## Owns the character's equipped items (M2.4 decision 2): EquipSlot -> the
## ItemInstance occupying it, or absent. Every mutation goes through the one
## Equip Gate (`Equipment.validate`) and applies/removes affixes as
## StatModifiers sourced by the ItemInstance (ADR-0001) -- equipping never
## mutates a Resource, the applied modifiers are transient runtime state
## rebuilt from the instance on load (ADR-0003/0015). Sibling of
## StatsComponent and InventoryComponent, found by the of() convention.

signal equipment_changed(slot: ItemTypes.EquipSlot)

var _equipped := {}

var _stats: StatsComponent
var _inventory: InventoryComponent

static func of(node: Node) -> EquipmentComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"EquipmentComponent") as EquipmentComponent

func _ready() -> void:
    _stats = StatsComponent.of(get_parent())
    _inventory = InventoryComponent.of(get_parent())
    if _stats == null:
        push_error("EquipmentComponent: no sibling StatsComponent found on %s, equipping is disabled" % get_parent())

## Validates at the one gate; on success, swaps out whatever occupied `slot`
## back to inventory, removes `item` from inventory, records it, and applies
## its mods. On failure applies nothing and returns the reason.
func equip(item: ItemInstance, slot: ItemTypes.EquipSlot) -> EquipResult:
    var result := Equipment.validate(item, slot, _stats)
    if not result.ok:
        return result

    var previous: ItemInstance = _equipped.get(slot)
    if previous != null:
        _equipped.erase(slot)
        if _stats != null:
            _stats.remove_by_source(previous)
        if _inventory != null:
            _inventory.add(previous)

    if _inventory != null:
        _inventory.remove(item)
    _equipped[slot] = item
    _apply_mods(item)
    equipment_changed.emit(slot)
    return result

## Removes the item's mods by source (the single ADR-0016-routed bulk path,
## decision 5) and returns it to inventory.
func unequip(slot: ItemTypes.EquipSlot) -> void:
    if not _equipped.has(slot):
        return
    var item: ItemInstance = _equipped[slot]
    _equipped.erase(slot)
    if _stats != null:
        _stats.remove_by_source(item)
    if _inventory != null:
        _inventory.add(item)
    equipment_changed.emit(slot)

func equipped(slot: ItemTypes.EquipSlot) -> ItemInstance:
    return _equipped.get(slot)

func all_equipped() -> Dictionary:
    return _equipped.duplicate()

## The slot an item would land in if dropped/clicked without picking a
## specific tile: rings go to the first free ring slot, else RING_1; every
## other ItemSlot maps to its one EquipSlot (decision 1). The UI's hover
## comparison and click-to-equip both call this so they agree with each
## other -- a second copy of "which slot does this item go to" is the same
## review failure as a second copy of the Equip Gate.
static func default_slot_for(item: ItemInstance, equipment: EquipmentComponent) -> Variant:
    if item == null:
        return null
    var def := item.definition()
    if def == null:
        return null
    if def.slot == ItemTypes.ItemSlot.RING:
        if equipment == null or equipment.equipped(ItemTypes.EquipSlot.RING_1) == null:
            return ItemTypes.EquipSlot.RING_1
        return ItemTypes.EquipSlot.RING_2
    for slot in ItemTypes.EquipSlot.values():
        if ItemTypes.accepts(slot, def.slot):
            return slot
    return null

## Character-file section: `{<EquipSlot name>: {def_id, rarity, affixes}}`,
## same instance shape as inventory (decision 6).
func save_state() -> Dictionary:
    var out := {}
    var names := ItemTypes.EquipSlot.keys()
    for slot in _equipped:
        out[names[slot]] = _equipped[slot].to_dict()
    return out

## Rebuilds each stored slot's ItemInstance and re-validates it against the
## CURRENT character at the same gate the UI uses (decision 6). Legal items
## are equipped (mods applied); illegal ones (e.g. a respec below the
## requirement) are NOT added to inventory here -- inventory hasn't loaded
## yet at this point in the load order (decision 7), so they're returned for
## the caller (SaveManager) to fold into the inventory section before
## InventoryComponent.load_state runs. Never a silent equip.
func load_state(section: Dictionary) -> Array:
    for slot in _equipped.keys().duplicate():
        var item: ItemInstance = _equipped[slot]
        _equipped.erase(slot)
        if _stats != null:
            _stats.remove_by_source(item)

    var displaced: Array = []
    var names := ItemTypes.EquipSlot.keys()
    for slot_name in section:
        var idx: int = names.find(slot_name)
        if idx == -1:
            continue
        var slot: ItemTypes.EquipSlot = idx as ItemTypes.EquipSlot
        var item := ItemInstance.from_dict(section[slot_name])
        var result := Equipment.validate(item, slot, _stats)
        if result.ok:
            _equipped[slot] = item
            _apply_mods(item)
            equipment_changed.emit(slot)
        else:
            push_warning("EquipmentComponent.load_state: %s no longer qualifies for %s (%s), moved to inventory" % [item.definition_id, slot_name, result.reason])
            displaced.append(item)
    return displaced

func _apply_mods(item: ItemInstance) -> void:
    if _stats == null:
        return
    var sources: Array = []
    var def := item.definition()
    if def != null:
        sources.append_array(def.implicit_mods)
    sources.append_array(item.rolled_affixes)
    for src in sources:
        var triple := ItemAffix.triple(src)
        var mod := StatModifier.new()
        mod.stat = triple.stat
        mod.op = triple.op
        mod.value = triple.value
        mod.source = item
        mod.duration = 0.0
        _stats.add_modifier(mod)
