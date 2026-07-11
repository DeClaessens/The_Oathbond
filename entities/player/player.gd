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
    var ember_bolt: Skill = load("res://skills/library/ember_bolt.tres")
    var smite: Skill = load("res://skills/library/smite.tres")
    learn_skill(sprint)
    learn_skill(super_jump)
    learn_skill(ember_bolt)
    learn_skill(smite)
    abilities.equip(sprint, 0)
    abilities.equip(super_jump, 1)
    abilities.equip(ember_bolt, 2)
    abilities.equip(smite, 3)

func learn_skill(skill: Skill) -> void:
    if skill in known_skills:
        return
    known_skills.append(skill)
    skill_learned.emit(skill)

## Learn-then-equip in one call: the Save Gate empties an equipped slot whose
## id isn't in known_skills, so the Skills Window must never equip without
## learning first (ADR-0015).
func grant_and_equip(skill: Skill, index: int) -> void:
    learn_skill(skill)
    abilities.equip(skill, index)

## Player-level character-file section: known/equipped skills persist as
## Skill.id through the SkillCatalog, never as resource paths (ADR-0015).
func save_skill_state() -> Dictionary:
    var known: Array = []
    for skill in known_skills:
        known.append(String(skill.id))
    var equipped: Array = []
    for slot in abilities.slots:
        equipped.append(String(slot.skill.id) if slot != null else null)
    return {"known": known, "equipped": equipped}

## Loading replaces the authored default kit: clears known_skills, learns
## every known id via the catalog, unequips all slots, then re-equips each
## non-null slot by id.
func load_skill_state(data: Dictionary) -> void:
    known_skills.clear()
    for id in data.get("known", []):
        var skill := SkillCatalog.by_id(StringName(id))
        if skill != null:
            learn_skill(skill)

    for i in AbilityComponent.SLOT_COUNT:
        abilities.unequip(i)
    var equipped: Array = data.get("equipped", [])
    for i in equipped.size():
        var id = equipped[i]
        if id == null:
            continue
        var skill := SkillCatalog.by_id(StringName(id))
        if skill != null:
            abilities.equip(skill, i)

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
