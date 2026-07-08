class_name LootComponent
extends Node

## Drops rolled gear when this component's parent (the victim) dies to a killer
## that carries an InventoryComponent. Sibling of XpRewardComponent: the drop
## comes from the victim (decision 8), spawned as a world DroppedItem
## (decision 9) at the victim's position.

const DroppedItemScene := preload("res://items/dropped_item/dropped_item.tscn")

@export var drop_table: Array[ItemDefinition] = []
@export var drop_chance: float = 1.0

static func of(node: Node) -> LootComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"LootComponent") as LootComponent

func _ready() -> void:
    Events.character_died.connect(_on_character_died)

func _on_character_died(victim: Node, killer: Node) -> void:
    if victim != get_parent():
        return
    if InventoryComponent.of(killer) == null:
        return
    if drop_table.is_empty():
        return
    if randf() > drop_chance:
        return
    var definition: ItemDefinition = drop_table[randi() % drop_table.size()]
    if definition == null:
        return
    _spawn_pickup(ItemRoller.roll(definition), victim)

func _spawn_pickup(instance: ItemInstance, victim: Node) -> void:
    var parent := victim.get_parent()
    if parent == null:
        push_error("LootComponent: victim %s has no parent to spawn the pickup into" % victim)
        return
    var pickup: DroppedItem = DroppedItemScene.instantiate()
    pickup.setup(instance)
    parent.add_child(pickup)
    if victim is Node2D:
        pickup.global_position = (victim as Node2D).global_position
