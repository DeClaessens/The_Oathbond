class_name TargetPreviewComponent
extends Node

## Preview of the resolver AbilityComponent's ENEMY cast path will use --
## calls the exact same TargetSelection.find_enemy every frame, against the
## live mouse position, and toggles HighlightComponent on the result. Never
## implement hover via mouse_entered/input_pickable or any second detection
## mechanism -- two code paths disagree at the edges.
##
## Preview range is the targeting_range of the first ENEMY-targeted skill
## across slots 0-3. No ENEMY skill equipped means no preview at all.
## Multiple equipped ENEMY skills with different ranges make the single
## highlight approximate for the others -- a known, accepted M0
## simplification.

var _current_target: Node

static func of(node: Node) -> TargetPreviewComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"TargetPreviewComponent") as TargetPreviewComponent

func current_target() -> Node:
    return _current_target

func _process(_delta: float) -> void:
    var caster := get_parent()
    if caster is Node2D:
        update_preview((caster as Node2D).get_global_mouse_position())

func update_preview(aim_point: Vector2) -> void:
    var caster := get_parent()
    var abilities := caster.get_node_or_null(^"AbilityComponent") as AbilityComponent
    var skill := _first_enemy_skill(abilities)

    var next_target: Node = null
    if skill != null and caster is Node2D:
        next_target = TargetSelection.find_enemy(caster, (caster as Node2D).global_position, aim_point, skill.targeting_range)
    _set_target(next_target)

static func _first_enemy_skill(abilities: AbilityComponent) -> Skill:
    if abilities == null:
        return null
    for slot in abilities.slots:
        if slot != null and slot.skill != null and slot.skill.targeting == Skill.Targeting.ENEMY:
            return slot.skill
    return null

func _set_target(next_target: Node) -> void:
    if next_target == _current_target:
        return
    if is_instance_valid(_current_target):
        var previous := HighlightComponent.of(_current_target)
        if previous != null:
            previous.set_highlighted(false)
    _current_target = next_target
    if _current_target != null:
        var highlight := HighlightComponent.of(_current_target)
        if highlight != null:
            highlight.set_highlighted(true)
