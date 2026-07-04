extends GutTest

## SkillBar binding model, exercised against a FAKE ability component (a plain
## Node exposing the same signals, a `slots` array, and SLOT_COUNT). We assert on
## each SkillSlot's observable state() rather than on tween/render internals.

const SkillBarScene := preload("res://ui/skill_bar/skill_bar.tscn")


class FakeAbilities extends Node:
    signal skill_activated(index: int, skill: Skill)
    signal skill_failed(index: int, reason: StringName)
    signal cooldown_changed(index: int, remaining: float, total: float)
    signal slot_changed(index: int, skill: Skill)

    const SLOT_COUNT := 4
    var slots: Array = [null, null, null, null]


func _make_skill(display_name: String, cooldown: float = 10.0) -> Skill:
    var skill := Skill.new()
    skill.display_name = display_name
    skill.cooldown = cooldown
    return skill

func _make_slot(skill: Skill) -> AbilitySlot:
    var slot := AbilitySlot.new()
    slot.skill = skill
    return slot

func _build() -> Array:
    var fake := FakeAbilities.new()
    add_child_autofree(fake)
    var bar: SkillBar = SkillBarScene.instantiate()
    add_child_autofree(bar)
    return [bar, fake]


func test_initial_paint_fills_occupied_slots_and_leaves_others_empty():
    var built := _build()
    var bar: SkillBar = built[0]
    var fake: FakeAbilities = built[1]
    var sprint := _make_skill("Sprint")
    var super_jump := _make_skill("Super Jump")
    fake.slots = [_make_slot(sprint), _make_slot(super_jump), null, null]

    bar.bind(fake)

    assert_true(bar._slots[0].state()["filled"], "slot 0 filled")
    assert_eq(bar._slots[0].state()["letter"], "S")
    assert_true(bar._slots[1].state()["filled"], "slot 1 filled")
    assert_eq(bar._slots[1].state()["letter"], "S")
    assert_false(bar._slots[2].state()["filled"], "slot 2 empty")
    assert_false(bar._slots[3].state()["filled"], "slot 3 empty")

func test_cooldown_changed_drives_fraction_and_seconds():
    var built := _build()
    var bar: SkillBar = built[0]
    var fake: FakeAbilities = built[1]
    fake.slots = [_make_slot(_make_skill("Sprint")), null, null, null]
    bar.bind(fake)

    fake.cooldown_changed.emit(0, 5.0, 10.0)

    var s := bar._slots[0].state()
    assert_almost_eq(s["fraction"], 0.5, 0.0001)
    assert_eq(s["seconds"], "5")
    assert_true(s["seconds_visible"])

func test_cooldown_reaching_zero_reads_ready():
    var built := _build()
    var bar: SkillBar = built[0]
    var fake: FakeAbilities = built[1]
    fake.slots = [_make_slot(_make_skill("Sprint")), null, null, null]
    bar.bind(fake)

    fake.cooldown_changed.emit(0, 5.0, 10.0)
    fake.cooldown_changed.emit(0, 0.0, 10.0)

    var s := bar._slots[0].state()
    assert_eq(s["fraction"], 0.0)
    assert_false(s["seconds_visible"], "seconds hidden when ready")
    assert_eq(s["ready_plays"], 1, "ready transition fired once")

func test_slot_changed_fills_a_previously_empty_slot():
    var built := _build()
    var bar: SkillBar = built[0]
    var fake: FakeAbilities = built[1]
    bar.bind(fake)
    assert_false(bar._slots[2].state()["filled"])

    fake.slot_changed.emit(2, _make_skill("Fireball"))

    assert_true(bar._slots[2].state()["filled"])
    assert_eq(bar._slots[2].state()["letter"], "F")

func test_slot_changed_null_empties_a_slot():
    var built := _build()
    var bar: SkillBar = built[0]
    var fake: FakeAbilities = built[1]
    fake.slots = [_make_slot(_make_skill("Sprint")), null, null, null]
    bar.bind(fake)
    assert_true(bar._slots[0].state()["filled"])

    fake.slot_changed.emit(0, null)

    assert_false(bar._slots[0].state()["filled"])

func test_skill_failed_plays_the_fail_feedback():
    var built := _build()
    var bar: SkillBar = built[0]
    var fake: FakeAbilities = built[1]
    fake.slots = [null, _make_slot(_make_skill("Sprint")), null, null]
    bar.bind(fake)

    fake.skill_failed.emit(1, &"on_cooldown")

    assert_eq(bar._slots[1].state()["fail_plays"], 1)
