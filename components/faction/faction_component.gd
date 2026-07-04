class_name FactionComponent
extends Node

## Identity only — no hostility/relationship resolution here.
## That's the future target-selection system's job.

enum Faction {
    PLAYER,
    ENEMY,
    NEUTRAL,
}

@export var faction: Faction = Faction.NEUTRAL

static func of(node: Node) -> FactionComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"FactionComponent") as FactionComponent
