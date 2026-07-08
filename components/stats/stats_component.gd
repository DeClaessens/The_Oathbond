class_name StatsComponent
extends Node

## Temporary stat changes use modifiers, not base_stats.
## Read get_stat() every frame — do not cache.

@export var base_stats: Dictionary = {}

## The fixed one-way derivation table (ADR-0016): source attribute -> array
## of [derived_stat, per_point_factor]. Sources are always attributes;
## deriveds are never themselves sources -- cycles are impossible by
## construction, not by a runtime check. Adding a derivation is a one-line
## edit here; confirm any component caching the derived stat refreshes on
## its key.
const DERIVATIONS := {
    &"might": [[&"max_health", 2.0]],
    &"wit":   [[&"max_mana", 1.0]],
    &"grace": [[&"crit_multi", 0.005]],
}

var _mods: Array[StatModifier] = []

signal stat_changed(stat: StringName, value: float)

static func of(node: Node) -> StatsComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"StatsComponent") as StatsComponent

func get_stat(stat: StringName) -> float:
    var base: float = float(base_stats.get(stat, 0.0)) + _derived_contribution(stat)
    return _compose(base, _mods_for(stat))

## Resolves `stat`'s derived contribution from DERIVATIONS at the FLAT tier
## (ADR-0016): get_stat(source) composes the source attribute's own base +
## mods, so the derived value tracks the total attribute including gear, and
## +% modifiers on the derived stat itself still amplify it downstream in
## _compose. Single recursion level (derived -> source, never further).
func _derived_contribution(stat: StringName) -> float:
    var total := 0.0
    for source in DERIVATIONS:
        for pair in DERIVATIONS[source]:
            if pair[0] == stat:
                total += get_stat(source) * pair[1]
    return total

func scale_outgoing(base: float, type: StatKeys.DamageType) -> float:
    return _compose(base, _mods_for(StatKeys.dmg(StatKeys.damage_type_name(type))))

## The single outgoing-damage entry point (ADR-0017): `scale_outgoing` stays
## the deterministic dmg_<type> seam; crit is a caster-level roll layered
## outside it so both damage call sites share one code path.
func roll_outgoing(base: float, type: StatKeys.DamageType) -> DamagePacket:
    var amount := scale_outgoing(base, type)
    var is_crit := randf() < clampf(get_stat(StatKeys.CRIT_CHANCE), 0.0, 1.0)
    if is_crit:
        amount *= maxf(1.0, get_stat(StatKeys.CRIT_MULTI))
    return DamagePacket.new(amount, type, is_crit)

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
                    existing.stat = mod.stat
                    existing.op = mod.op
                    existing.value = mod.value
                    existing.duration = mod.duration
                    existing.source = mod.source
                    existing.remaining = mod.duration
                    _emit_stat_changed(existing.stat)
                    return
            StatModifier.StackMode.STACK:
                var cap := maxi(mod.max_stacks, 1)
                var same_key := _mods_by_key(mod.key)
                if same_key.size() >= cap:
                    _mods.erase(same_key[0])

    mod.remaining = mod.duration
    _mods.append(mod)
    _emit_stat_changed(mod.stat)

func remove_modifier(mod: StatModifier) -> void:
    if _mods.has(mod):
        _mods.erase(mod)
        _emit_stat_changed(mod.stat)

## The single site every `stat_changed` emission funnels through (ADR-0016):
## emits for `stat` itself, then for every derived stat that has `stat` as a
## DERIVATIONS source, so cached pools (HealthComponent, ManaComponent) never
## go stale when an attribute moves. Called from every emit site -- add_modifier
## (both the REFRESH and normal paths), remove_modifier, and the _process
## expiry sweep -- so no future emit site can forget it.
func _emit_stat_changed(stat: StringName) -> void:
    stat_changed.emit(stat, get_stat(stat))
    if DERIVATIONS.has(stat):
        for pair in DERIVATIONS[stat]:
            var derived: StringName = pair[0]
            stat_changed.emit(derived, get_stat(derived))

func _find_by_key(key: StringName) -> StatModifier:
    for m in _mods:
        if m.key == key:
            return m
    return null

func _mods_by_key(key: StringName) -> Array[StatModifier]:
    var out: Array[StatModifier] = []
    for m in _mods:
        if m.key == key:
            out.append(m)
    return out

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
            _emit_stat_changed(s)

func mitigate_incoming(raw: float, type: StatKeys.DamageType) -> float:
    var resist := clampf(get_stat(StatKeys.resist(StatKeys.damage_type_name(type))), 0.0, 0.9)
    return raw * (1.0 - resist)
