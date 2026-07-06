extends Node2D

@onready var player: Player = $Player
@onready var hud: SkillBar = $SkillBarHUD

func _ready() -> void:
    hud.bind(player.abilities)
