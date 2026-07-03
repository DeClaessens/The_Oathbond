class_name StatsComponent
extends Node

## THE authority on a character's numbers, incoming and outgoing.
## Attach as a child named exactly "StatsComponent" to any character that can
## deal or receive scaled numbers (player AND enemies).
##
## - base_stats holds permanent base values (health, move_speed, ...).
##   NEVER mutate base_stats at runtime for temporary effects — use modifiers.
##   apply_damage is the ONE exception: HP loss is a permanent base change.
## - Modifiers (buffs/debuffs/gear/talents) are added via add_modifier and
##   composed on every get_stat / scale_outgoing call. Movement code must read
##   get_stat() EVERY FRAME — never cache it.

@export var base_stats: Dictionary = {}

var _mods: Array[StatModifier] = []

signal stat_changed(stat: StringName, value: float)

## --- lookup ------------------------------------------------------------

## Resolve the StatsComponent belonging to any node. Single point of coupling
## to the node name — effects and projectiles call this, never a raw path.
static func of(node: Node) -> StatsComponent:
	if node == null:
		return null
	return node.get_node_or_null(^"StatsComponent") as StatsComponent

func get_stat(stat: StringName) -> float:
	return _compose(float(base_stats.get(stat, 0.0)), _mods_for(stat))

## Outgoing scaling: seed the formula with the SKILL's base, not a character
## stat. With no offensive modifiers this returns `base` unchanged. This is the
## single seam to replace when a richer DamagePacket/crit/talent pipeline lands.
func scale_outgoing(base: float, type: StringName) -> float:
	return _compose(base, _mods_for(StatKeys.dmg(type)))

## Shared composition: (base + Σflat) × (1 + Σadd) × Π(1 + mult).
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

## --- modifiers ---------------------------------------------------------

## Add a modifier. If it carries a `key`, apply the stacking policy:
##   REFRESH (implemented): if a modifier with the same key exists, reset its
##                          remaining window; do NOT add a second entry (no
##                          magnitude compounding). This is Sprint's behavior.
##   STACK   (reserved):    see §3.5 — not yet implemented; asserts loudly.
func add_modifier(mod: StatModifier) -> void:
	if mod.key != &"":
		match mod.stack_mode:
			StatModifier.StackMode.REFRESH:
				var existing := _find_by_key(mod.key)
				if existing != null:
					existing.remaining = mod.duration    # reset the 5s window
					stat_changed.emit(existing.stat, get_stat(existing.stat))
					return
			StatModifier.StackMode.STACK:
				assert(false, "STACK mode not implemented yet — see handoff §3.5")

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

## Remaining time on a keyed buff — for a future cooldown/buff HUD.
func time_remaining(key: StringName) -> float:
	var m := _find_by_key(key)
	return m.remaining if m != null else 0.0

## Tick timed modifiers. Permanent mods (duration <= 0) are never touched.
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

## --- damage ------------------------------------------------------------

## Incoming damage. `raw` is the already-caster-scaled amount. This node is the
## authority on the FINAL value after resistance, so it — and only it — emits the
## damage event. Resistance is treated as a 0..0.9 fraction for now (a seam;
## a future defense pipeline can replace this body).
func apply_damage(raw: float, type: StringName, source: Node) -> void:
	var resist := clampf(get_stat(StatKeys.resist(type)), 0.0, 0.9)
	var final_amount := raw * (1.0 - resist)
	var hp := float(base_stats.get(StatKeys.HEALTH, 0.0))
	hp = maxf(0.0, hp - final_amount)
	base_stats[StatKeys.HEALTH] = hp
	stat_changed.emit(StatKeys.HEALTH, hp)
	if Engine.has_singleton("Events") or (typeof(Events) != TYPE_NIL):
		Events.damage_dealt.emit(source, owner, int(round(final_amount)), type)
