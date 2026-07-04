extends GutTest

func test_format_seconds_ready_is_empty():
    assert_eq(SkillSlot.format_seconds(0.0), "")

func test_format_seconds_ceils_to_integer():
    assert_eq(SkillSlot.format_seconds(2.9), "3")
    assert_eq(SkillSlot.format_seconds(0.01), "1")

func test_cooldown_fraction_is_the_ratio():
    assert_almost_eq(SkillSlot.cooldown_fraction(5.0, 10.0), 0.5, 0.0001)

func test_cooldown_fraction_clamps_to_unit_range():
    assert_eq(SkillSlot.cooldown_fraction(20.0, 10.0), 1.0)
    assert_eq(SkillSlot.cooldown_fraction(-5.0, 10.0), 0.0)

func test_cooldown_fraction_with_zero_total_is_zero():
    assert_eq(SkillSlot.cooldown_fraction(5.0, 0.0), 0.0)

func test_keybind_label_reads_the_input_map():
    assert_eq(SkillSlot.keybind_label(0), "1")

func test_keybind_label_falls_back_for_unmapped_index():
    assert_false(InputMap.has_action(&"skill_9"))
    assert_eq(SkillSlot.keybind_label(8), "9")

func test_first_letter_is_upper_case_initial():
    assert_eq(SkillSlot.first_letter("Sprint"), "S")
    assert_eq(SkillSlot.first_letter("super jump"), "S")

func test_first_letter_of_empty_name_is_placeholder():
    assert_eq(SkillSlot.first_letter(""), "?")
