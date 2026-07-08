class_name DroppedItem
extends Area2D

## A world pickup carrying one rolled ItemInstance. Shows the definition's
## icon; on body-entered by a node with an InventoryComponent, adds the
## instance and frees itself. If add refuses (inventory full), stays in the
## world. Collision per ADR-0008: masks the Player layer only (it is a
## detector, not a hittable side, so it occupies no layer of its own).

var instance: ItemInstance

@onready var _sprite: Sprite2D = $Sprite2D

func _ready() -> void:
    body_entered.connect(_on_body_entered)
    _refresh_icon()

func setup(item: ItemInstance) -> void:
    instance = item
    if is_node_ready():
        _refresh_icon()

func _refresh_icon() -> void:
    if _sprite == null or instance == null:
        return
    var def := instance.definition()
    if def != null and def.icon != null:
        _sprite.texture = def.icon

func _on_body_entered(body: Node) -> void:
    var inventory := InventoryComponent.of(body)
    if inventory == null:
        return
    if inventory.add(instance):
        queue_free()
