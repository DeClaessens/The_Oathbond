class_name ExperienceComponent
extends Node

## Character progression: level (starts 1) and XP within the current level.
## Awards itself off Events.character_died when this component's parent is
## the killer -- there is no separate "XP system" node.
##
## Local signals only (not Events): the only consumer today is UI.

signal experience_changed(current: int, to_next: int)
signal leveled_up(new_level: int)

const HEALTH_GROWTH_PER_LEVEL := 10.0
const MANA_GROWTH_PER_LEVEL := 5.0

var _level: int = 1
var _xp: int = 0
var _stats: StatsComponent

static func of(node: Node) -> ExperienceComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"ExperienceComponent") as ExperienceComponent

func _ready() -> void:
    _stats = StatsComponent.of(get_parent())
    if _stats == null:
        push_error("ExperienceComponent: no sibling StatsComponent found on %s, level-up growth is disabled" % get_parent())
    Events.character_died.connect(_on_character_died)

func level() -> int:
    return _level

func xp() -> int:
    return _xp

static func xp_to_next(for_level: int) -> int:
    return roundi(50.0 * pow(for_level, 1.5))

func award_xp(amount: int) -> void:
    if amount <= 0:
        return
    _xp += amount
    var to_next := xp_to_next(_level)
    while _xp >= to_next:
        _xp -= to_next
        _level += 1
        _apply_level_up_growth()
        leveled_up.emit(_level)
        to_next = xp_to_next(_level)
    experience_changed.emit(_xp, to_next)

## Character-file section: level and in-level XP only. Growth is replayed
## from level on load, never serialized (ADR-0015) -- _mods entries are
## unkeyed and source refs don't survive JSON.
func save_state() -> Dictionary:
    return {"level": _level, "xp": _xp}

## Sets level/xp directly and replays growth modifiers for every level above
## 1 -- never calls the level-up full restore, so pools' own load_state
## (which runs after this, per the fixed load order) owns the persisted
## current values.
func load_state(data: Dictionary) -> void:
    _level = int(data.get("level", 1))
    _xp = int(data.get("xp", 0))
    for level in range(2, _level + 1):
        _apply_growth_modifiers()
    experience_changed.emit(_xp, xp_to_next(_level))

func _apply_level_up_growth() -> void:
    _apply_growth_modifiers()
    var health := HealthComponent.of(get_parent())
    if health != null:
        health.restore_full()
    var mana := ManaComponent.of(get_parent())
    if mana != null:
        mana.restore_full()

func _apply_growth_modifiers() -> void:
    if _stats == null:
        return
    var health_mod := StatModifier.new()
    health_mod.stat = StatKeys.MAX_HEALTH
    health_mod.op = StatModifier.Op.FLAT
    health_mod.value = HEALTH_GROWTH_PER_LEVEL
    _stats.add_modifier(health_mod)

    var mana_mod := StatModifier.new()
    mana_mod.stat = StatKeys.MAX_MANA
    mana_mod.op = StatModifier.Op.FLAT
    mana_mod.value = MANA_GROWTH_PER_LEVEL
    _stats.add_modifier(mana_mod)

func _on_character_died(victim: Node, killer: Node) -> void:
    if killer == null or killer == victim or killer != get_parent():
        return
    var reward := XpRewardComponent.of(victim)
    if reward == null:
        return
    award_xp(reward.amount)
