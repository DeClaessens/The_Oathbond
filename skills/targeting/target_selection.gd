class_name TargetSelection
extends RefCounted

## Stateless resolver for "who would I hit" — hostility rules plus
## snap-to-cursor-with-fallback candidate selection over the &"characters"
## group. Single source of truth: both the cast path (AbilityComponent) and
## the future target-highlight preview (M0-05) call this, never their own
## logic, or hover and cast will disagree at the edges.

const SNAP_RADIUS := 100.0

static func is_hostile(a: FactionComponent.Faction, b: FactionComponent.Faction) -> bool:
    if a == FactionComponent.Faction.NEUTRAL or b == FactionComponent.Faction.NEUTRAL:
        return false
    return a != b

static func is_allied(a: FactionComponent.Faction, b: FactionComponent.Faction) -> bool:
    return a == b

static func find_enemy(caster: Node, caster_position: Vector2, aim_point: Vector2, max_range: float) -> Node:
    return _find(caster, caster_position, aim_point, max_range, true)

static func find_ally(caster: Node, caster_position: Vector2, aim_point: Vector2, max_range: float) -> Node:
    return _find(caster, caster_position, aim_point, max_range, false)

static func _find(caster: Node, caster_position: Vector2, aim_point: Vector2, max_range: float, want_hostile: bool) -> Node:
    var caster_faction := FactionComponent.of(caster)
    if caster_faction == null or caster == null or not caster.is_inside_tree():
        return null

    var candidates: Array[Node] = []
    for node in caster.get_tree().get_nodes_in_group(&"characters"):
        var faction := FactionComponent.of(node)
        if faction == null:
            continue
        var matches := is_hostile(caster_faction.faction, faction.faction) if want_hostile else is_allied(caster_faction.faction, faction.faction)
        if not matches:
            continue
        var health := HealthComponent.of(node)
        if health != null and health.is_dead():
            continue
        if max_range > 0.0 and (node as Node2D).global_position.distance_to(caster_position) > max_range:
            continue
        candidates.append(node)

    if candidates.is_empty():
        return null

    var snap_target: Node = null
    var snap_distance := INF
    for node in candidates:
        var distance := (node as Node2D).global_position.distance_to(aim_point)
        if distance <= SNAP_RADIUS and distance < snap_distance:
            snap_distance = distance
            snap_target = node
    if snap_target != null:
        return snap_target

    var fallback_target: Node = null
    var fallback_distance := INF
    for node in candidates:
        var distance := (node as Node2D).global_position.distance_to(caster_position)
        if distance < fallback_distance:
            fallback_distance = distance
            fallback_target = node
    return fallback_target
