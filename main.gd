extends Node2D

## Composition root: wires the read-only Skill Bar HUD to the player's
## AbilityComponent. Cross-node binding lives here, not inside the HUD or Player.

@onready var player: Player = $Player
@onready var hud: SkillBar = $SkillBarHUD

func _ready() -> void:
	hud.bind(player.abilities)
