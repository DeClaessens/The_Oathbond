extends GutTest

func _valid_document() -> Dictionary:
    return {
        "version": 1,
        "id": "default",
        "experience": {"level": 3, "xp": 12},
        "attributes": {"allocated": {"might": 2, "grace": 1, "wit": 0}, "unspent": 4},
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
    assert_eq(out.attributes, {"allocated": {"might": 2, "grace": 1, "wit": 0}, "unspent": 4})
    assert_eq(out.health, {"current": 57.0})
    assert_eq(out.mana, {"current": 20.0})
    assert_eq(out.skills.known, ["sprint", "super_jump", "spark", "smite"])
    assert_eq(out.skills.equipped, ["sprint", "super_jump", "spark", "smite"])

func test_missing_sections_default_and_warn():
    var out := SaveValidator.validate_character({})
    assert_eq(out.experience, {"level": 1, "xp": 0})
    assert_eq(out.attributes, {"allocated": {"might": 0, "grace": 0, "wit": 0}, "unspent": 0})
    assert_eq(out.health, {"current": 0.0})
    assert_eq(out.mana, {"current": 0.0})
    assert_eq(out.skills, {"known": [], "equipped": [null, null, null, null]})
    assert_push_warning("missing/invalid experience section")

func test_missing_attributes_section_defaults_silently_since_it_is_additive_optional():
    var data := _valid_document()
    data.erase("attributes")
    var out := SaveValidator.validate_character(data)
    assert_eq(out.attributes, {"allocated": {"might": 0, "grace": 0, "wit": 0}, "unspent": 0})
    assert_push_warning_count(0, "a v1 document lacking the attributes section entirely must not warn")

func test_attributes_unknown_key_is_dropped_with_a_warning():
    var data := _valid_document()
    data.attributes = {"allocated": {"might": 1, "not_an_attribute": 5}, "unspent": 0}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.attributes.allocated, {"might": 1, "grace": 0, "wit": 0})
    assert_push_warning("unknown key")

func test_attributes_missing_key_defaults_to_zero():
    var data := _valid_document()
    data.attributes = {"allocated": {"might": 3}, "unspent": 0}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.attributes.allocated, {"might": 3, "grace": 0, "wit": 0})

func test_attributes_negative_allocated_count_clamps_to_zero_with_a_warning():
    var data := _valid_document()
    data.attributes = {"allocated": {"might": -4, "grace": 0, "wit": 0}, "unspent": 0}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.attributes.allocated.might, 0)
    assert_push_warning("negative")

func test_attributes_mistyped_unspent_defaults_to_zero_with_a_warning():
    var data := _valid_document()
    data.attributes = {"allocated": {"might": 0, "grace": 0, "wit": 0}, "unspent": "lots"}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.attributes.unspent, 0)
    assert_push_warning("attributes.unspent")

func test_attributes_negative_unspent_clamps_to_zero_with_a_warning():
    var data := _valid_document()
    data.attributes = {"allocated": {"might": 0, "grace": 0, "wit": 0}, "unspent": -2}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.attributes.unspent, 0)
    assert_push_warning("attributes.unspent")

func test_non_dictionary_attributes_section_defaults_with_a_warning():
    var data := _valid_document()
    data.attributes = "not a dictionary"
    var out := SaveValidator.validate_character(data)
    assert_eq(out.attributes, {"allocated": {"might": 0, "grace": 0, "wit": 0}, "unspent": 0})
    assert_push_warning("invalid attributes section")

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

func test_non_numeric_level_defaults_to_one_with_warning():
    var data := _valid_document()
    data.experience = {"level": "three", "xp": 0}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.experience.level, 1)
    assert_push_warning("experience.level")

func test_non_numeric_xp_defaults_to_zero_with_warning():
    var data := _valid_document()
    data.experience = {"level": 2, "xp": "lots"}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.experience.xp, 0)
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

func test_non_array_known_defaults_to_empty_with_warning():
    var data := _valid_document()
    data.skills = {"known": "sprint", "equipped": [null, null, null, null]}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.skills.known, [])
    assert_push_warning("skills.known")

func test_non_array_equipped_defaults_to_empty_slots_with_warning():
    var data := _valid_document()
    data.skills = {"known": ["sprint"], "equipped": "sprint"}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.skills.equipped, [null, null, null, null])
    assert_push_warning("skills.equipped")

func test_mistyped_skills_section_defaults():
    var data := _valid_document()
    data.skills = "not a dictionary"
    var out := SaveValidator.validate_character(data)
    assert_eq(out.skills, {"known": [], "equipped": [null, null, null, null]})
    assert_push_warning_count(1, "an invalid section must warn once, not re-warn per field inside it")

func test_non_dictionary_document_defaults_everything():
    var out := SaveValidator.validate_character({"totally": "unrelated"})
    assert_eq(out.experience, {"level": 1, "xp": 0})
    assert_eq(out.health, {"current": 0.0})
    assert_eq(out.mana, {"current": 0.0})
    assert_eq(out.skills, {"known": [], "equipped": [null, null, null, null]})
    assert_eq(out.inventory, [], "a document with no inventory yields an empty section")

# --- inventory section (M2.3) ---

func _inventory_entry(def_id := "rusted_sickle", rarity = 1, affixes = null) -> Dictionary:
    return {
        "def_id": def_id,
        "rarity": rarity,
        "affixes": affixes if affixes != null else [{"stat": "dmg_ember", "op": 0, "value": 5.0}],
    }

func test_valid_inventory_passes_through():
    var data := _valid_document()
    data["inventory"] = [_inventory_entry()]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.inventory.size(), 1)
    assert_eq(out.inventory[0].def_id, "rusted_sickle")
    assert_eq(out.inventory[0].rarity, 1)
    assert_eq(out.inventory[0].affixes[0], {"stat": "dmg_ember", "op": 0, "value": 5.0})

func test_missing_inventory_defaults_to_empty_without_warning():
    var out := SaveValidator.validate_character(_valid_document())
    assert_eq(out.inventory, [])
    assert_push_warning_count(0)

func test_non_array_inventory_defaults_to_empty_with_warning():
    var data := _valid_document()
    data["inventory"] = "not an array"
    var out := SaveValidator.validate_character(data)
    assert_eq(out.inventory, [])
    assert_push_warning("inventory is not an array")

func test_unknown_def_id_entry_is_dropped():
    var data := _valid_document()
    data["inventory"] = [_inventory_entry("not_a_real_item")]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.inventory, [])
    assert_push_warning("does not resolve")

func test_out_of_range_rarity_is_clamped():
    var data := _valid_document()
    data["inventory"] = [_inventory_entry("rusted_sickle", 99)]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.inventory[0].rarity, int(ItemTypes.Rarity.HEIRLOOM))
    assert_push_warning("out of range")

func test_non_numeric_rarity_defaults_to_common():
    var data := _valid_document()
    data["inventory"] = [_inventory_entry("rusted_sickle", "shiny")]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.inventory[0].rarity, int(ItemTypes.Rarity.COMMON))
    assert_push_warning("not numeric")

func test_malformed_affix_is_dropped_but_the_entry_survives():
    var data := _valid_document()
    data["inventory"] = [_inventory_entry("rusted_sickle", 2, [
        {"stat": "dmg_ember", "op": 0, "value": 5.0},
        {"stat": "", "op": 0, "value": 1.0},
        {"op": 0, "value": 1.0},
        "not a dict",
    ])]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.inventory.size(), 1)
    assert_eq(out.inventory[0].affixes.size(), 1, "only the well-formed affix survives")
    assert_push_warning("malformed affix dropped")

func test_out_of_range_op_affix_is_dropped():
    var data := _valid_document()
    data["inventory"] = [_inventory_entry("rusted_sickle", 1, [{"stat": "dmg_ember", "op": 9, "value": 5.0}])]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.inventory[0].affixes.size(), 0)
    assert_push_warning("op 9 out of range")

func test_non_dictionary_inventory_entry_is_dropped():
    var data := _valid_document()
    data["inventory"] = ["not a dict", _inventory_entry()]
    var out := SaveValidator.validate_character(data)
    assert_eq(out.inventory.size(), 1)
    assert_push_warning("inventory entry is not a dictionary")

# --- equipment section (M2.4) ---

func test_valid_equipment_passes_through():
    var data := _valid_document()
    data["equipment"] = {"BODY": _inventory_entry("worn_hide")}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.equipment.keys(), ["BODY"])
    assert_eq(out.equipment["BODY"].def_id, "worn_hide")

func test_missing_equipment_defaults_to_empty_without_warning():
    var out := SaveValidator.validate_character(_valid_document())
    assert_eq(out.equipment, {})
    assert_push_warning_count(0)

func test_non_dictionary_equipment_defaults_to_empty_with_warning():
    var data := _valid_document()
    data["equipment"] = "not a dictionary"
    var out := SaveValidator.validate_character(data)
    assert_eq(out.equipment, {})
    assert_push_warning("equipment is not a dictionary")

func test_unknown_equip_slot_name_is_dropped():
    var data := _valid_document()
    data["equipment"] = {"NOT_A_SLOT": _inventory_entry("worn_hide")}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.equipment, {})
    assert_push_warning("unknown")

func test_equipment_unknown_def_id_entry_is_dropped():
    var data := _valid_document()
    data["equipment"] = {"BODY": _inventory_entry("not_a_real_item")}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.equipment, {})
    assert_push_warning("does not resolve")

func test_equipment_out_of_range_rarity_is_clamped():
    var data := _valid_document()
    data["equipment"] = {"WEAPON": _inventory_entry("rusted_sickle", 99)}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.equipment["WEAPON"].rarity, int(ItemTypes.Rarity.HEIRLOOM))
    assert_push_warning("out of range")

func test_equipment_malformed_affix_is_dropped_but_entry_survives():
    var data := _valid_document()
    data["equipment"] = {"WEAPON": _inventory_entry("rusted_sickle", 1, [
        {"stat": "dmg_ember", "op": 0, "value": 5.0},
        {"op": 0, "value": 1.0},
    ])}
    var out := SaveValidator.validate_character(data)
    assert_eq(out.equipment["WEAPON"].affixes.size(), 1)
    assert_push_warning("malformed affix dropped")
