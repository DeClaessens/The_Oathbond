class_name HealthComponent
extends Node2D

## Owns the current-HP Resource Pool. Max Health is still a Stat on the
## sibling StatsComponent -- resolved once at _ready() and re-read from
## stat_changed if it ever moves (e.g. a future Max Health buff).

signal health_changed(current: float, max: float)

var _current: float
var _max: float
var _stats: StatsComponent

static func of(node: Node) -> HealthComponent:
	if node == null:
		return null
	return node.get_node_or_null(^"HealthComponent") as HealthComponent

func _ready() -> void:
	_stats = StatsComponent.of(get_parent())
	_max = _stats.get_stat(StatKeys.MAX_HEALTH)
	_current = _max
	_stats.stat_changed.connect(_on_stat_changed)

	var bar: HealthBar = preload("res://components/health/health_bar.tscn").instantiate()
	add_child(bar)
	bar.bind(self)

func current() -> float:
	return _current

func max_health() -> float:
	return _max

func fraction() -> float:
	return 0.0 if _max <= 0.0 else clampf(_current / _max, 0.0, 1.0)

func apply_damage(raw: float, type: StatKeys.DamageType, source: Node) -> void:
	var final_amount := _stats.mitigate_incoming(raw, type)
	_current = clampf(_current - final_amount, 0.0, _max)
	health_changed.emit(_current, _max)
	Events.damage_dealt.emit(source, owner, int(round(final_amount)), type)

func _on_stat_changed(stat: StringName, value: float) -> void:
	if stat == StatKeys.MAX_HEALTH:
		_max = value
		_current = minf(_current, _max)
		health_changed.emit(_current, _max)
