class_name Player
extends CharacterBody2D

@onready var stats: StatsComponent = $StatsComponent
@onready var abilities: AbilityComponent = $AbilityComponent

var gravity: int = ProjectSettings.get_setting("physics/2d/default_gravity")

## Skills this character has learned, independent of what's equipped in a slot.
## A future skill-book UI reads/appends this; an ability-bar UI drags an entry
## from here into AbilityComponent.equip(skill, index). Learning and equipping
## are deliberately separate actions.
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
    # slot 2/3 reserved: projectile / enemy-targeted, wired when enemies exist

    # Optional but recommended while integrating — see cooldown feedback live:
    abilities.skill_failed.connect(func(i, reason): print("skill %d failed: %s" % [i, reason]))

func learn_skill(skill: Skill) -> void:
    if skill in known_skills:
        return
    known_skills.append(skill)
    skill_learned.emit(skill)

func _physics_process(delta: float) -> void:
    if not is_on_floor():
        velocity.y += gravity * delta

    if Input.is_action_just_pressed(&"jump") and is_on_floor():
        velocity.y = -stats.get_stat(StatKeys.JUMP_VELOCITY)      # read EVERY frame

    var direction := Input.get_axis(&"move_left", &"move_right")
    var speed := stats.get_stat(StatKeys.MOVE_SPEED)              # read EVERY frame
    if direction:
        velocity.x = direction * speed
    else:
        velocity.x = move_toward(velocity.x, 0.0, speed)

    move_and_slide()

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"skill_1"):
        abilities.try_activate(0, [self])
    elif event.is_action_pressed(&"skill_2"):
        abilities.try_activate(1, [self])
    elif event.is_action_pressed(&"skill_3"):
        # directional example for when a projectile skill is equipped in slot 2
        var dir := (get_global_mouse_position() - global_position).normalized()
        abilities.activate_with_direction(2, dir)
    elif event.is_action_pressed(&"skill_4"):
        abilities.try_activate(3, [self])   # placeholder until enemy targeting exists
