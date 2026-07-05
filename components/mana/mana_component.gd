class_name ManaComponent
extends Node2D

## Owns the current-Mana Resource Pool. Max Mana and Mana Regen are Stats on
## the sibling StatsComponent -- resolved at _ready() and re-read from
## stat_changed if either ever moves (e.g. a future Max Mana buff).

signal mana_changed(current: float, max: float)

var _current: float
var _max: float
var _stats: StatsComponent

static func of(node: Node) -> ManaComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"ManaComponent") as ManaComponent

func _ready() -> void:
    _stats = StatsComponent.of(get_parent())
    if _stats == null:
        push_error("ManaComponent: no sibling StatsComponent found on %s, mana pool is malformed (max mana 0.0, regen disabled)" % get_parent())
        return
    _max = _stats.get_stat(StatKeys.MAX_MANA)
    _current = _max
    _stats.stat_changed.connect(_on_stat_changed)

    var bar: ManaBar = preload("res://components/mana/mana_bar.tscn").instantiate()
    add_child(bar)
    bar.bind(self)

func current() -> float:
    return _current

func max_mana() -> float:
    return _max

func fraction() -> float:
    return 0.0 if _max <= 0.0 else clampf(_current / _max, 0.0, 1.0)

func can_afford(cost: float) -> bool:
    return _current >= cost

func spend(amount: float) -> void:
    _current = clampf(_current - amount, 0.0, _max)
    mana_changed.emit(_current, _max)

func _process(delta: float) -> void:
    if _stats == null or _current >= _max:
        return
    var regen := _stats.get_stat(StatKeys.MANA_REGEN)
    if regen <= 0.0:
        return
    _current = minf(_current + regen * delta, _max)
    mana_changed.emit(_current, _max)

func _on_stat_changed(stat: StringName, value: float) -> void:
    if stat == StatKeys.MAX_MANA:
        _max = value
        _current = minf(_current, _max)
        mana_changed.emit(_current, _max)
