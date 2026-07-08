extends GutTest

func _valid_document() -> Dictionary:
    return {
        "version": 1,
        "id": "default",
        "experience": {"level": 3, "xp": 12},
        "health": {"current": 57.0},
        "mana": {"current": 20.0},
        "skills": {
            "known": ["sprint", "super_jump", "spark", "smite"],
            "equipped": ["sprint", "super_jump", "spark", "smite"],
        },
    }

func test_valid_document_passes_through_unchanged():
    var out := SaveValidator.validate_character(_valid_document())
    assert_eq(out.experience, {"level": 3, "xp": 12})
    assert_eq(out.health, {"current": 57.0})
    assert_eq(out.mana, {"current": 20.0})
    assert_eq(out.skills.known, ["sprint", "super_jump", "spark", "smite"])
    assert_eq(out.skills.equipped, ["sprint", "super_jump", "spark", "smite"])

func test_missing_sections_default_and_warn():
    var out := SaveValidator.validate_character({})
    assert_eq(out.experience, {"level": 1, "xp": 0})
    assert_eq(out.health, {"current": 0.0})
    assert_eq(out.mana, {"current": 0.0})
    assert_eq(out.skills, {"known": [], "equipped": [null, null, null, null]})
    assert_push_warning("missing/invalid experience section")

func test_level_below_one_is_clamped_to_one():
    var data := _valid_document()
    data.experience.level = 0
    var out := SaveValidator.validate_character(data)
    assert_eq(out.experience.level, 1)
    assert_push_warning("experience.level")

func test_xp_out_of_range_is_clamped():
    var data := _valid_document()
    data.experience = {"level": 1, "xp": 999999}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.experience.xp, ExperienceComponent.xp_to_next(1) - 1)
    assert_push_warning("experience.xp")

func test_non_numeric_pool_current_defaults_to_zero():
    var data := _valid_document()
    data.health = {"current": "a lot"}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.health.current, 0.0)
    assert_push_warning("health.current")

func test_unknown_skill_id_is_dropped_from_known():
    var data := _valid_document()
    data.skills.known = ["sprint", "not_a_real_skill"]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.skills.known, ["sprint"])
    assert_push_warning("skills.known")

func test_equipped_id_missing_from_known_becomes_empty_slot():
    var data := _valid_document()
    data.skills.known = ["sprint"]
    data.skills.equipped = ["sprint", "super_jump", null, null]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.skills.equipped, ["sprint", null, null, null])
    assert_push_warning("skills.equipped")

func test_equipped_is_padded_and_truncated_to_slot_count():
    var data := _valid_document()
    data.skills.equipped = ["sprint"]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.skills.equipped.size(), AbilityComponent.SLOT_COUNT)

func test_mistyped_skills_section_defaults():
    var data := _valid_document()
    data.skills = "not a dictionary"
    var out := SaveValidator.validate_character(data)
    assert_eq(out.skills, {"known": [], "equipped": [null, null, null, null]})

func test_non_dictionary_document_defaults_everything():
    var out := SaveValidator.validate_character({"totally": "unrelated"})
    assert_eq(out.experience, {"level": 1, "xp": 0})
    assert_eq(out.health, {"current": 0.0})
    assert_eq(out.mana, {"current": 0.0})
    assert_eq(out.skills, {"known": [], "equipped": [null, null, null, null]})
