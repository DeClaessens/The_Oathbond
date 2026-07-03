class_name StatsComponent
extends Node

## Temporary stat changes use modifiers, not base_stats (apply_damage excepted).
## Read get_stat() every frame — do not cache.

@export var base_stats: Dictionary = {}

var _mods: Array[StatModifier] = []

signal stat_changed(stat: StringName, value: float)

static func of(node: Node) -> StatsComponent:
	if node == null:
		return null
	return node.get_node_or_null(^"StatsComponent") as StatsComponent

func get_stat(stat: StringName) -> float:
	return _compose(float(base_stats.get(stat, 0.0)), _mods_for(stat))

func scale_outgoing(base: float, type: StringName) -> float:
	return _compose(base, _mods_for(StatKeys.dmg(type)))

func _compose(base: float, mods: Array[StatModifier]) -> float:
	var flat := 0.0
	var add := 0.0
	var mult := 1.0
	for m in mods:
		match m.op:
			StatModifier.Op.FLAT:     flat += m.value
			StatModifier.Op.ADD_PCT:  add  += m.value
			StatModifier.Op.MULT_PCT: mult *= (1.0 + m.value)
	return (base + flat) * (1.0 + add) * mult

func _mods_for(stat: StringName) -> Array[StatModifier]:
	var out: Array[StatModifier] = []
	for m in _mods:
		if m.stat == stat:
			out.append(m)
	return out

func add_modifier(mod: StatModifier) -> void:
	if mod.key != &"":
		match mod.stack_mode:
			StatModifier.StackMode.REFRESH:
				var existing := _find_by_key(mod.key)
				if existing != null:
					existing.remaining = mod.duration
					stat_changed.emit(existing.stat, get_stat(existing.stat))
					return
			StatModifier.StackMode.STACK:
				assert(false, "STACK mode not implemented")

	mod.remaining = mod.duration
	_mods.append(mod)
	stat_changed.emit(mod.stat, get_stat(mod.stat))

func remove_modifier(mod: StatModifier) -> void:
	if _mods.has(mod):
		_mods.erase(mod)
		stat_changed.emit(mod.stat, get_stat(mod.stat))

func _find_by_key(key: StringName) -> StatModifier:
	for m in _mods:
		if m.key == key:
			return m
	return null

func time_remaining(key: StringName) -> float:
	var m := _find_by_key(key)
	return m.remaining if m != null else 0.0

func _process(delta: float) -> void:
	if _mods.is_empty():
		return
	var expired_stats := {}
	var survivors: Array[StatModifier] = []
	for m in _mods:
		if m.duration <= 0.0:
			survivors.append(m)
			continue
		m.remaining = maxf(0.0, m.remaining - delta)
		if m.remaining > 0.0:
			survivors.append(m)
		else:
			expired_stats[m.stat] = true
	if not expired_stats.is_empty():
		_mods = survivors
		for s in expired_stats:
			stat_changed.emit(s, get_stat(s))

func apply_damage(raw: float, type: StringName, source: Node) -> void:
	var resist := clampf(get_stat(StatKeys.resist(type)), 0.0, 0.9)
	var final_amount := raw * (1.0 - resist)
	var hp := float(base_stats.get(StatKeys.HEALTH, 0.0))
	hp = maxf(0.0, hp - final_amount)
	base_stats[StatKeys.HEALTH] = hp
	stat_changed.emit(StatKeys.HEALTH, hp)
	Events.damage_dealt.emit(source, owner, int(round(final_amount)), type)
