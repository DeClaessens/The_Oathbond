class_name SkillBar
extends CanvasLayer

## Read-only HUD mirroring a character's Ability Slots. It binds directly to one
## AbilityComponent (not the Events bus) and forwards that component's per-slot
## signals to the matching SkillSlot view. It never equips or activates.

const SkillSlotScene := preload("res://ui/skill_bar/skill_slot.tscn")

## Duck-typed: the real AbilityComponent, or any Node exposing the same signals,
## a `slots` array, and `SLOT_COUNT`. Loosened from AbilityComponent so the HUD
## can be unit-tested against a fake (see test/ui/test_skill_bar.gd).
var _abilities: Node

var _slots: Array[SkillSlot] = []

@onready var _hbox: HBoxContainer = $MarginContainer/HBoxContainer

func _ready() -> void:
    var margin: MarginContainer = $MarginContainer
    # Anchor to the bottom-centre POINT (zero anchor-span) and grow upward, so the
    # container's size tracks its content min size whenever the HBox re-sorts. A
    # min-size preset sampled here would read zero (slots aren't added yet) and
    # freeze the bar off the bottom edge.
    margin.anchor_left = 0.5
    margin.anchor_right = 0.5
    margin.anchor_top = 1.0
    margin.anchor_bottom = 1.0
    margin.grow_horizontal = Control.GROW_DIRECTION_BOTH
    margin.grow_vertical = Control.GROW_DIRECTION_BEGIN
    margin.offset_top = -24.0    # 24px of clearance above the bottom edge
    margin.offset_bottom = -24.0
    _hbox.alignment = BoxContainer.ALIGNMENT_CENTER
    _hbox.add_theme_constant_override("separation", 8)
    for i in AbilityComponent.SLOT_COUNT:
        var slot: SkillSlot = SkillSlotScene.instantiate()
        slot.index = i
        _hbox.add_child(slot)
        _slots.append(slot)

func bind(abilities: Node) -> void:
    if _abilities != null:
        _abilities.skill_activated.disconnect(_on_skill_activated)
        _abilities.cooldown_changed.disconnect(_on_cooldown_changed)
        _abilities.skill_ready.disconnect(_on_skill_ready)
        _abilities.skill_failed.disconnect(_on_skill_failed)
        _abilities.slot_changed.disconnect(_on_slot_changed)
    _abilities = abilities
    abilities.skill_activated.connect(_on_skill_activated)
    abilities.cooldown_changed.connect(_on_cooldown_changed)
    abilities.skill_ready.connect(_on_skill_ready)
    abilities.skill_failed.connect(_on_skill_failed)
    abilities.slot_changed.connect(_on_slot_changed)
    for i in AbilityComponent.SLOT_COUNT:
        var slot = abilities.slots[i]
        _slots[i].set_skill(slot.skill if slot else null)
        if slot != null and slot.cooldown_remaining > 0.0:
            _slots[i].set_cooldown(slot.cooldown_remaining, slot.skill.cooldown)

func _on_skill_activated(index: int, skill: Skill) -> void:
    _slots[index].begin_cooldown(skill.cooldown)

func _on_cooldown_changed(index: int, remaining: float, total: float) -> void:
    _slots[index].set_cooldown(remaining, total)

func _on_skill_ready(index: int) -> void:
    _slots[index].play_ready()

func _on_skill_failed(index: int, _reason: StringName) -> void:
    _slots[index].play_fail()

func _on_slot_changed(index: int, skill: Skill) -> void:
    _slots[index].set_skill(skill)
