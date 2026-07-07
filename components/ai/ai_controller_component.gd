class_name AiControllerComponent
extends Node

## Drives a CharacterBody2D parent through IDLE/CHASE/ATTACK. Hostility and
## detection both come from TargetSelection (skills/targeting/target_selection.gd)
## -- the AI invents no hostility logic of its own. Attacking means calling
## AbilityComponent.activate(): the AI never builds a SkillContext or touches
## effects directly.

enum State { IDLE, CHASE, ATTACK }

@export var aggro_range := 400.0
@export var skill: Skill

var state: State = State.IDLE

var _body: CharacterBody2D
var _stats: StatsComponent
var _abilities: AbilityComponent
var _gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
    _body = get_parent() as CharacterBody2D
    if _body == null:
        push_error("AiControllerComponent: parent is not a CharacterBody2D, AI is disabled")
        return
    _stats = StatsComponent.of(_body)
    _abilities = _body.get_node_or_null(^"AbilityComponent") as AbilityComponent
    if _abilities != null:
        _abilities.caster = _body
        if skill != null:
            _abilities.equip(skill, 0)

func _physics_process(delta: float) -> void:
    if _body == null:
        return
    if not _body.is_on_floor():
        _body.velocity.y += _gravity * delta

    var target := TargetSelection.find_enemy(_body, _body.global_position, _body.global_position, aggro_range)
    if target == null:
        state = State.IDLE
        _body.velocity.x = 0.0
    else:
        var target_position: Vector2 = (target as Node2D).global_position
        if _body.global_position.distance_to(target_position) <= _attack_range():
            state = State.ATTACK
            _body.velocity.x = 0.0
            if _abilities != null:
                _abilities.activate(0, target_position)
        else:
            state = State.CHASE
            var speed := _stats.get_stat(StatKeys.MOVE_SPEED) if _stats != null else 0.0
            _body.velocity.x = signf(target_position.x - _body.global_position.x) * speed

    _body.move_and_slide()

func _attack_range() -> float:
    if _abilities == null or _abilities.slots.is_empty():
        return 0.0
    var slot := _abilities.slots[0]
    return slot.skill.targeting_range if slot != null and slot.skill != null else 0.0
