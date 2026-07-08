class_name InventoryComponent
extends Node

## Holds a character's rolled ItemInstances (RefCounted save data, ADR-0003).
## Capacity-bound: over-capacity adds are refused and the caller leaves the
## drop in the world. Persists through the Save Gate as plain dicts (ADR-0015);
## its character-file section is an array of {def_id, rarity, affixes:[...]}.

signal inventory_changed

const CAPACITY := 40

var _items: Array[ItemInstance] = []

static func of(node: Node) -> InventoryComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"InventoryComponent") as InventoryComponent

## Returns false (leaving the item unheld) when at capacity or given null.
func add(item: ItemInstance) -> bool:
    if item == null:
        return false
    if _items.size() >= CAPACITY:
        return false
    _items.append(item)
    inventory_changed.emit()
    return true

func remove(item: ItemInstance) -> bool:
    var idx := _items.find(item)
    if idx == -1:
        return false
    _items.remove_at(idx)
    inventory_changed.emit()
    return true

func items() -> Array:
    return _items.duplicate()

func size() -> int:
    return _items.size()

## Section is an array (not a dict): the document's "inventory" key holds it
## directly. Each ItemInstance serializes as a plain dict.
func save_state() -> Array:
    var out: Array = []
    for item in _items:
        out.append(item.to_dict())
    return out

## Rebuilds instances from a section already sanitized by the Save Gate.
func load_state(section: Array) -> void:
    _items.clear()
    for entry in section:
        _items.append(ItemInstance.from_dict(entry))
    inventory_changed.emit()
