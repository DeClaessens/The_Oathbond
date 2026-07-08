class_name ItemCatalog
extends Resource

## Authored id -> ItemDefinition registry (res://items/item_catalog.tres): the
## only legal way to resolve a persisted ItemInstance.definition_id (ADR-0015),
## since save data never stores resource paths. Every ItemDefinition under
## items/library/ must be listed here -- one completeness rule, no exceptions.
## Twin of SkillCatalog.

const CATALOG_PATH := "res://items/item_catalog.tres"

@export var items: Array[ItemDefinition] = []

static var _by_id: Dictionary = {}
static var _loaded: bool = false

## Loads the authored catalog once (lazy static Dictionary) and resolves a
## persisted definition_id, or null if the id is unknown. Duplicate or empty
## ids in the catalog are authoring errors, surfaced with push_error.
static func by_id(id: StringName) -> ItemDefinition:
    _ensure_loaded()
    return _by_id.get(id)

static func _ensure_loaded() -> void:
    if _loaded:
        return
    _loaded = true
    var catalog: ItemCatalog = load(CATALOG_PATH)
    if catalog == null:
        push_error("ItemCatalog: failed to load %s" % CATALOG_PATH)
        return
    for item in catalog.items:
        if item == null:
            continue
        if item.id == &"":
            push_error("ItemCatalog: item asset %s has an empty id" % item.resource_path)
            continue
        if _by_id.has(item.id):
            push_error("ItemCatalog: duplicate item id %s" % item.id)
            continue
        _by_id[item.id] = item
