class_name AttributesComponent
extends Node

## Owns attribute allocation (Might/Grace/Wit) as its source of truth.
## Applies each attribute's allocated count as a single permanent FLAT
## StatModifier on that attribute stat, keyed per-attribute so re-allocation
## REFRESHes rather than stacks; StatsComponent's ADR-0016 dependent emission
## moves the derived stats (max_health, max_mana, crit_multi) whenever the
## allocation changes. Sibling of StatsComponent, found by the of() convention.
##
## Points come from ExperienceComponent's leveled_up signal. Local signals
## only (not Events): the only consumer today is UI.

signal attributes_changed()
signal points_changed(unspent: int)

const POINTS_PER_LEVEL := 3
const STARTING_POINTS := 3

## No class starting spread yet (M5/M6) -- base attribute values start at 0.
## A future class system's hook is here: give this component a settable
## base allocation before _ready runs, or seed _allocated directly.
const ATTRS: Array[StringName] = [StatKeys.MIGHT, StatKeys.GRACE, StatKeys.WIT]

var _allocated := {StatKeys.MIGHT: 0, StatKeys.GRACE: 0, StatKeys.WIT: 0}
var _unspent: int = 0

var _stats: StatsComponent
var _experience: ExperienceComponent

static func of(node: Node) -> AttributesComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"AttributesComponent") as AttributesComponent

func _ready() -> void:
    _stats = StatsComponent.of(get_parent())
    if _stats == null:
        push_error("AttributesComponent: no sibling StatsComponent found on %s, allocation is disabled" % get_parent())
    _experience = ExperienceComponent.of(get_parent())
    if _experience != null:
        _experience.leveled_up.connect(_on_leveled_up)
    _unspent = STARTING_POINTS
    points_changed.emit(_unspent)

func unspent() -> int:
    return _unspent

func allocated(attr: StringName) -> int:
    return int(_allocated.get(attr, 0))

## Spends one unspent point into `attr`. Returns false (no-op) when there is
## nothing to spend or `attr` is not one of the three known attributes.
func allocate(attr: StringName) -> bool:
    if _unspent <= 0 or not _allocated.has(attr):
        return false
    _unspent -= 1
    _allocated[attr] += 1
    _apply_modifiers()
    points_changed.emit(_unspent)
    attributes_changed.emit()
    return true

## Returns every allocated point to unspent. Free and unlimited at M2 -- no
## currency system exists yet; a respec cost is a future economy hook
## ("cheap early, real later", docs/design/stats-and-gear.md), not M2 scope.
func respec() -> void:
    for attr in ATTRS:
        _unspent += int(_allocated[attr])
        _allocated[attr] = 0
    _apply_modifiers()
    points_changed.emit(_unspent)
    attributes_changed.emit()

## Character-file section: allocated counts and unspent only -- the
## StatModifiers themselves are never serialized (ADR-0015 replay discipline).
func save_state() -> Dictionary:
    var allocated_out := {}
    for attr in ATTRS:
        allocated_out[String(attr)] = int(_allocated[attr])
    return {"allocated": allocated_out, "unspent": _unspent}

## Sets the counts directly and reapplies the modifiers -- never double-
## applies, since _apply_modifiers REFRESHes each attribute's single keyed
## modifier rather than stacking a new one.
func load_state(data: Dictionary) -> void:
    var allocated_in: Dictionary = data.get("allocated", {})
    for attr in ATTRS:
        _allocated[attr] = int(allocated_in.get(String(attr), 0))
    _unspent = int(data.get("unspent", 0))
    _apply_modifiers()
    points_changed.emit(_unspent)
    attributes_changed.emit()

func _on_leveled_up(_new_level: int) -> void:
    _unspent += POINTS_PER_LEVEL
    points_changed.emit(_unspent)

func _apply_modifiers() -> void:
    if _stats == null:
        return
    for attr in ATTRS:
        var mod := StatModifier.new()
        mod.stat = attr
        mod.op = StatModifier.Op.FLAT
        mod.value = float(_allocated[attr])
        mod.key = StringName("attribute_%s" % attr)
        mod.stack_mode = StatModifier.StackMode.REFRESH
        mod.duration = 0.0
        mod.source = self
        _stats.add_modifier(mod)
