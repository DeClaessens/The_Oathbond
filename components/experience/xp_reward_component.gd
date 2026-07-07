class_name XpRewardComponent
extends Node

## Data only: how much XP this character's death grants its killer.
## Not a Stat -- the reward isn't modifiable by buffs (ADR-0009 reasoning).

@export var amount: int = 10

static func of(node: Node) -> XpRewardComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"XpRewardComponent") as XpRewardComponent
