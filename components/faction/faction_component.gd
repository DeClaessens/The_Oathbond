class_name FactionComponent
extends Node

## Identity only — no hostility/relationship resolution here.
## That's TargetSelection's job (skills/targeting/target_selection.gd).

enum Faction {
    PLAYER,
    ENEMY,
    NEUTRAL,
}

@export var faction: Faction = Faction.NEUTRAL

func _ready() -> void:
    get_parent().add_to_group(&"characters")

static func of(node: Node) -> FactionComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"FactionComponent") as FactionComponent
