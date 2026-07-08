class_name ItemDefinition
extends Resource

## The authored base item type (a "Sickle"): the definition half of the
## ADR-0003 definition/instance split (third appearance, mirroring the
## skill/save split). Rolled drops are ItemInstances (RefCounted save data) --
## rolling never mutates a definition.

@export var id: StringName = &""
@export var display_name: String = ""
@export var icon: Texture2D
@export var slot: ItemTypes.ItemSlot = ItemTypes.ItemSlot.WEAPON
@export var material: ItemTypes.ItemMaterial = ItemTypes.ItemMaterial.NONE

## Fixed mods every instance of this definition carries (a Sickle's base
## damage). AffixEntry, not ItemAffix, because @export typed arrays require a
## Resource element -- authored with min_value == max_value for a fixed value.
@export var implicit_mods: Array[AffixEntry] = []

@export var affix_pool: AffixPool

## Read by M2.4's equip gate (e.g. {&"might": 10}); authored now, unused here.
@export var attribute_requirement: Dictionary = {}
