extends Node2D

@onready var player: Player = $Player
@onready var hud: SkillBar = $SkillBarHUD
@onready var level: Level = $ProvingGrounds
@onready var inventory_panel: InventoryPanel = $InventoryPanel

func _ready() -> void:
    hud.bind(player.abilities)
    inventory_panel.bind(InventoryComponent.of(player))

    var camera: Camera2D = player.get_node(^"Camera2D")
    camera.limit_left = int(level.bounds.position.x)
    camera.limit_top = int(level.bounds.position.y)
    camera.limit_right = int(level.bounds.end.x)
    camera.limit_bottom = int(level.bounds.end.y)

    SaveManager.load_character(player)
