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

static func family_for_slot(slot: ItemSlot) -> Family:
    match slot:
        ItemSlot.WEAPON:
            return Family.WEAPON
        ItemSlot.OFF_HAND, ItemSlot.HELM, ItemSlot.BODY, ItemSlot.GLOVES, ItemSlot.BOOTS, ItemSlot.BELT:
            return Family.ARMOR
        ItemSlot.AMULET, ItemSlot.RING, ItemSlot.RELIC:
            return Family.JEWELRY
    return Family.ARMOR
