class_name ItemTypes
extends RefCounted

## Shared item enums and the slot->family mapping. Every enum here is
## append-only with a frozen order (ADR-0005/0011 spirit) -- saved instances
## store the int, so reordering would silently corrupt existing saves.

## The equip-slot roster (decision 4). Ring x2 is two equip slots over one
## RING item type -- that split is M2.4's concern, not this enum's.
enum ItemSlot {
    WEAPON,
    OFF_HAND,
    HELM,
    BODY,
    GLOVES,
    BOOTS,
    BELT,
    AMULET,
    RING,
    RELIC,
}

## Material tag an armor slot carries (the Sower's oath speaks in materials).
## Jewelry, weapons, and relics use NONE. Named ItemMaterial rather than the
## brief's bare Material because Material shadows Godot's native Resource class.
enum ItemMaterial {
    NONE,
    METAL,
    LEATHER,
    WOVEN,
}

## Rarity tiers (decision 2). HEIRLOOM exists but is never rolled -- Heirlooms
## are hand-authored (out of scope here).
enum Rarity {
    COMMON,
    QUALITY,
    MASTERWORK,
    HEIRLOOM,
}

## Slot-family: which affix pool a slot draws from (decision 3).
enum Family {
    WEAPON,
    ARMOR,
    JEWELRY,
}

## The eleven body slots an item equips INTO (M2.4 decision 1) -- distinct
## from ItemSlot above (the ten item TYPES). RING is the only ItemSlot legal
## in more than one EquipSlot (RING_1 or RING_2); every other ItemSlot maps
## to exactly one EquipSlot 1:1. Append-only, frozen order -- EquipmentComponent
## persists these as their key NAME (not the int), so reordering is safe for
## saves, but never reorder ItemSlot above without checking ADR-0005/0011.
enum EquipSlot {
    WEAPON,
    OFF_HAND,
    HELM,
    BODY,
    GLOVES,
    BOOTS,
    BELT,
    AMULET,
    RING_1,
    RING_2,
    RELIC,
}

## The slot-match rule (decision 1): RING_1/RING_2 both accept an ItemSlot.RING
## item; every other EquipSlot requires the exact matching ItemSlot.
static func accepts(equip_slot: EquipSlot, item_slot: ItemSlot) -> bool:
    match equip_slot:
        EquipSlot.RING_1, EquipSlot.RING_2:
            return item_slot == ItemSlot.RING
        EquipSlot.WEAPON:
            return item_slot == ItemSlot.WEAPON
        EquipSlot.OFF_HAND:
            return item_slot == ItemSlot.OFF_HAND
        EquipSlot.HELM:
            return item_slot == ItemSlot.HELM
        EquipSlot.BODY:
            return item_slot == ItemSlot.BODY
        EquipSlot.GLOVES:
            return item_slot == ItemSlot.GLOVES
        EquipSlot.BOOTS:
            return item_slot == ItemSlot.BOOTS
        EquipSlot.BELT:
            return item_slot == ItemSlot.BELT
        EquipSlot.AMULET:
            return item_slot == ItemSlot.AMULET
        EquipSlot.RELIC:
            return item_slot == ItemSlot.RELIC
    return false

static func family_for_slot(slot: ItemSlot) -> Family:
    match slot:
        ItemSlot.WEAPON:
            return Family.WEAPON
        ItemSlot.OFF_HAND, ItemSlot.HELM, ItemSlot.BODY, ItemSlot.GLOVES, ItemSlot.BOOTS, ItemSlot.BELT:
            return Family.ARMOR
        ItemSlot.AMULET, ItemSlot.RING, ItemSlot.RELIC:
            return Family.JEWELRY
    return Family.ARMOR
