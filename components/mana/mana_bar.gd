class_name ManaBar
extends Node2D

const WIDTH := 48.0
const HEIGHT := 6.0
const BACKGROUND := Color(0.08, 0.1, 0.35)
const FOREGROUND := Color(0.25, 0.55, 0.95)

var _fraction: float = 1.0
var _bound_mana: ManaComponent

func _ready() -> void:
    position = Vector2(0, -66)
    visible = true

func bind(mana: ManaComponent) -> void:
    if _bound_mana != null and _bound_mana.mana_changed.is_connected(_on_mana_changed):
        _bound_mana.mana_changed.disconnect(_on_mana_changed)
    _bound_mana = mana
    _fraction = mana.fraction()
    mana.mana_changed.connect(_on_mana_changed)

func _on_mana_changed(current: float, max: float) -> void:
    _fraction = 0.0 if max <= 0.0 else clampf(current / max, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    draw_rect(Rect2(-WIDTH / 2.0, 0, WIDTH, HEIGHT), BACKGROUND)
    draw_rect(Rect2(-WIDTH / 2.0, 0, fill_width(_fraction, WIDTH), HEIGHT), FOREGROUND)

static func fill_width(fraction: float, total_width: float) -> float:
    return clampf(fraction, 0.0, 1.0) * total_width
