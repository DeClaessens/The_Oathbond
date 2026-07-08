class_name HealthComponent
extends Node2D

## Owns the current-HP Resource Pool. Max Health is still a Stat on the
## sibling StatsComponent -- resolved once at _ready() and re-read from
## stat_changed if it ever moves (e.g. a future Max Health buff).

signal health_changed(current: float, max: float)
signal died

var _current: float
var _max: float
var _dead: bool = false
var _stats: StatsComponent

static func of(node: Node) -> HealthComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"HealthComponent") as HealthComponent

func _ready() -> void:
    _stats = StatsComponent.of(get_parent())
    if _stats == null:
        push_error("HealthComponent: no sibling StatsComponent found on %s, damage is disabled" % get_parent())
        return
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

func is_dead() -> bool:
    return _dead

func apply_damage(raw: float, type: StatKeys.DamageType, source: Node) -> void:
    if _stats == null:
        push_error("HealthComponent.apply_damage: no StatsComponent resolved, ignoring damage")
        return
    if _dead:
        return
    var final_amount := maxf(0.0, _stats.mitigate_incoming(raw, type))
    _current = clampf(_current - final_amount, 0.0, _max)
    health_changed.emit(_current, _max)
    Events.damage_dealt.emit(source, get_parent(), int(round(final_amount)), type)
    if _current <= 0.0:
        _dead = true
        died.emit()
        Events.character_died.emit(get_parent(), source)

func restore_full() -> void:
    _dead = false
    _current = _max
    health_changed.emit(_current, _max)

## Character-file section: current only -- max is always derived from Stats
## and _dead is a transient latch, neither survives to disk (ADR-0015).
func save_state() -> Dictionary:
    return {"current": _current}

## A dead character is never resumed dead: current <= 0.0 loads as a full
## restore instead of a resumed corpse.
func load_state(data: Dictionary) -> void:
    var current: float = data.get("current", 0.0)
    if current <= 0.0:
        restore_full()
        return
    _dead = false
    _current = clampf(current, 0.0, _max)
    health_changed.emit(_current, _max)

func _on_stat_changed(stat: StringName, value: float) -> void:
    if stat == StatKeys.MAX_HEALTH:
        _max = value
        _current = minf(_current, _max)
        health_changed.emit(_current, _max)
