class_name HealthBar
extends Node2D

const WIDTH := 48.0
const HEIGHT := 6.0
const BACKGROUND := Color(0.5, 0.08, 0.08)
const FOREGROUND := Color(0.2, 0.85, 0.25)

var _fraction: float = 1.0

func _ready() -> void:
	position = Vector2(0, -74)
	visible = false

func bind(health: HealthComponent) -> void:
	health.health_changed.connect(_on_health_changed)

func _on_health_changed(current: float, max: float) -> void:
	print('health changed')
	if current < max:
		visible = true
	_fraction = 0.0 if max <= 0.0 else clampf(current / max, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(-WIDTH / 2.0, 0, WIDTH, HEIGHT), BACKGROUND)
	draw_rect(Rect2(-WIDTH / 2.0, 0, fill_width(_fraction, WIDTH), HEIGHT), FOREGROUND)

static func fill_width(fraction: float, total_width: float) -> float:
	return clampf(fraction, 0.0, 1.0) * total_width
