class_name Player
extends CharacterBody2D

@onready var stats: StatsComponent = $StatsComponent
@onready var abilities: AbilityComponent = $AbilityComponent

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

## Learned skills, separate from equipped slots.
signal skill_learned(skill: Skill)

var known_skills: Array[Skill] = []

func _ready() -> void:
    abilities.caster = self

    var sprint: Skill = load("res://skills/library/sprint.tres")
    var super_jump: Skill = load("res://skills/library/super_jump.tres")
    learn_skill(sprint)
    learn_skill(super_jump)
    abilities.equip(sprint, 0)
    abilities.equip(super_jump, 1)

func learn_skill(skill: Skill) -> void:
    if skill in known_skills:
        return
    known_skills.append(skill)
    skill_learned.emit(skill)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    if Input.is_action_just_pressed(&"jump") and is_on_floor():
        velocity.y = -stats.get_stat(StatKeys.JUMP_VELOCITY)

    var direction := Input.get_axis(&"move_left", &"move_right")
    var speed := stats.get_stat(StatKeys.MOVE_SPEED)
    if direction:
        velocity.x = direction * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed)

    move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"skill_1"):
        abilities.activate(0, get_global_mouse_position())
    elif event.is_action_pressed(&"skill_2"):
        abilities.activate(1, get_global_mouse_position())
    elif event.is_action_pressed(&"skill_3"):
        abilities.activate(2, get_global_mouse_position())
    elif event.is_action_pressed(&"skill_4"):
        abilities.activate(3, get_global_mouse_position())
