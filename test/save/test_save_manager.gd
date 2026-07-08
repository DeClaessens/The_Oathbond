extends GutTest

const PlayerScene := preload("res://entities/player/Player.tscn")
const SaveManagerScript := preload("res://save/save_manager.gd")

var manager
var scratch_root: String

func before_each():
    manager = SaveManagerScript.new()
    add_child_autofree(manager)
    scratch_root = "user://test_saves_%d/" % Time.get_ticks_usec()
    manager.save_root = scratch_root

func after_each():
    if DirAccess.dir_exists_absolute(scratch_root):
        _remove_recursive(scratch_root)

func _remove_recursive(path: String) -> void:
    var dir := DirAccess.open(path)
    if dir == null:
        return
    dir.list_dir_begin()
    var entry := dir.get_next()
    while entry != "":
        var full := path.path_join(entry)
        if dir.current_is_dir():
            _remove_recursive(full)
        else:
            DirAccess.remove_absolute(full)
        entry = dir.get_next()
    dir.list_dir_end()
    DirAccess.remove_absolute(path)

func _make_player() -> Player:
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)
    return player

func test_serialize_character_captures_played_state():
    var player := _make_player()
    var xp := ExperienceComponent.of(player)
    var attributes := AttributesComponent.of(player)
    var health := HealthComponent.of(player)
    var mana := ManaComponent.of(player)
    xp.award_xp(xp.xp_to_next(1) + xp.xp_to_next(2) + 3)
    attributes.allocate(StatKeys.MIGHT)
    health.apply_damage(20.0, StatKeys.DamageType.PHYSICAL, null)
    mana.spend(15.0)
    player.abilities.unequip(0)
    player.abilities.equip(SkillCatalog.by_id(&"spark"), 0)

    var data: Dictionary = manager.serialize_character(player)

    assert_eq(data.version, 1)
    assert_eq(data.id, "default")
    assert_eq(data.experience, xp.save_state())
    assert_eq(data.attributes, attributes.save_state())
    assert_eq(data.health, health.save_state())
    assert_eq(data.mana, mana.save_state())
    assert_eq(data.skills, player.save_skill_state())

func test_round_trip_restores_played_state_on_a_fresh_graph():
    var played := _make_player()
    var xp := ExperienceComponent.of(played)
    var attributes := AttributesComponent.of(played)
    var health := HealthComponent.of(played)
    var mana := ManaComponent.of(played)
    xp.award_xp(xp.xp_to_next(1) + xp.xp_to_next(2) + 3)
    attributes.allocate(StatKeys.MIGHT)
    attributes.allocate(StatKeys.WIT)
    health.apply_damage(20.0, StatKeys.DamageType.PHYSICAL, null)
    mana.spend(15.0)
    played.abilities.unequip(1)

    var data: Dictionary = manager.serialize_character(played)

    var fresh := _make_player()
    manager.apply_character(fresh, data)

    var fresh_xp := ExperienceComponent.of(fresh)
    var fresh_attributes := AttributesComponent.of(fresh)
    var fresh_health := HealthComponent.of(fresh)
    var fresh_mana := ManaComponent.of(fresh)
    var fresh_stats := StatsComponent.of(fresh)
    var played_stats := StatsComponent.of(played)

    assert_eq(fresh_xp.level(), xp.level())
    assert_eq(fresh_xp.xp(), xp.xp())
    assert_eq(fresh_attributes.save_state(), attributes.save_state())
    assert_eq(fresh_health.current(), health.current())
    assert_eq(fresh_mana.current(), mana.current())
    assert_eq(fresh_stats.get_stat(StatKeys.MAX_HEALTH), played_stats.get_stat(StatKeys.MAX_HEALTH))
    assert_eq(fresh.save_skill_state(), played.save_skill_state())

func test_load_order_applies_attributes_before_health_clamps_current():
    var fresh := _make_player()

    manager.apply_character(fresh, {
        "experience": {"level": 1, "xp": 0},
        "attributes": {"allocated": {"might": 10, "grace": 0, "wit": 0}, "unspent": 0},
        "health": {"current": 105.0},
    })

    var health := HealthComponent.of(fresh)
    assert_eq(health.max_health(), 120.0, "base 100 + 10 Might * 2.0 must already be applied before health.load_state clamps current")
    assert_eq(health.current(), 105.0, "the persisted current must survive the raised max, not be clamped against the pre-allocation max")

func test_replay_equivalence_load_matches_leveling_in_play():
    var played := _make_player()
    var xp := ExperienceComponent.of(played)
    for i in range(4):
        xp.award_xp(xp.xp_to_next(xp.level()))

    var loaded := _make_player()
    manager.apply_character(loaded, {"experience": {"level": xp.level(), "xp": xp.xp()}})

    var loaded_stats := StatsComponent.of(loaded)
    var played_stats := StatsComponent.of(played)
    assert_eq(loaded_stats.get_stat(StatKeys.MAX_HEALTH), played_stats.get_stat(StatKeys.MAX_HEALTH))
    assert_eq(ExperienceComponent.of(loaded).level(), xp.level())

func test_save_then_load_then_save_produces_identical_document():
    var played := _make_player()
    var xp := ExperienceComponent.of(played)
    var attributes := AttributesComponent.of(played)
    var health := HealthComponent.of(played)
    xp.award_xp(xp.xp_to_next(1) + 3)
    attributes.allocate(StatKeys.GRACE)
    health.apply_damage(10.0, StatKeys.DamageType.PHYSICAL, null)

    var first: Dictionary = manager.serialize_character(played)

    var reloaded := _make_player()
    manager.apply_character(reloaded, first)
    var second: Dictionary = manager.serialize_character(reloaded)

    assert_eq(second, first)

func test_save_and_load_round_trip_through_disk():
    var player := _make_player()
    var xp := ExperienceComponent.of(player)
    xp.award_xp(xp.xp_to_next(1) + 4)

    manager.save_character(player)

    assert_true(FileAccess.file_exists(scratch_root.path_join("characters/default.json")))
    assert_true(FileAccess.file_exists(scratch_root.path_join("account.json")))

    var account_file := FileAccess.open(scratch_root.path_join("account.json"), FileAccess.READ)
    var account = JSON.parse_string(account_file.get_as_text())
    account_file.close()
    assert_eq(account.characters, ["default"])

    var fresh := _make_player()
    var loaded: bool = manager.load_character(fresh)

    assert_true(loaded)
    assert_eq(ExperienceComponent.of(fresh).level(), xp.level())
    assert_eq(ExperienceComponent.of(fresh).xp(), xp.xp())

func test_load_with_no_save_file_returns_false_without_warnings():
    var player := _make_player()

    var loaded: bool = manager.load_character(player)

    assert_false(loaded)
    assert_push_warning_count(0)

func test_delete_character_removes_file_but_keeps_account():
    var player := _make_player()
    manager.save_character(player)

    manager.delete_character(&"default")

    assert_false(FileAccess.file_exists(scratch_root.path_join("characters/default.json")))
    assert_true(FileAccess.file_exists(scratch_root.path_join("account.json")))
    var account_file := FileAccess.open(scratch_root.path_join("account.json"), FileAccess.READ)
    var account = JSON.parse_string(account_file.get_as_text())
    account_file.close()
    assert_eq(account.characters, [])

func test_corrupt_character_file_is_quarantined_and_load_returns_false():
    var characters_dir := scratch_root.path_join("characters")
    DirAccess.make_dir_recursive_absolute(characters_dir)
    var path := characters_dir.path_join("default.json")
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string("{not valid json")
    file.close()

    var player := _make_player()
    var loaded: bool = manager.load_character(player)

    assert_false(loaded)
    assert_true(FileAccess.file_exists(path + ".corrupt"))
    assert_false(FileAccess.file_exists(path))
    assert_engine_error("JSON")
    assert_push_warning("quarantined")

func test_next_save_after_quarantine_writes_a_valid_file():
    var characters_dir := scratch_root.path_join("characters")
    DirAccess.make_dir_recursive_absolute(characters_dir)
    var path := characters_dir.path_join("default.json")
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string("{not valid json")
    file.close()

    var player := _make_player()
    manager.load_character(player)
    assert_engine_error("JSON")
    assert_push_warning("quarantined")

    manager.save_character(player)

    assert_true(FileAccess.file_exists(path))
    var saved_file := FileAccess.open(path, FileAccess.READ)
    var saved = JSON.parse_string(saved_file.get_as_text())
    saved_file.close()
    assert_eq(typeof(saved), TYPE_DICTIONARY)
    assert_eq(int(saved.version), SaveValidator.VERSION)

    var fresh := _make_player()
    assert_true(manager.load_character(fresh), "the post-quarantine save must load back")
    assert_push_warning_count(1, "reloading the fresh save must trigger no validator repairs")

func _roll_and_hold(player: Player, def_id: StringName) -> ItemInstance:
    var inst := ItemRoller.roll(ItemCatalog.by_id(def_id))
    InventoryComponent.of(player).add(inst)
    return inst

func test_inventory_round_trips_through_disk():
    var player := _make_player()
    var held := _roll_and_hold(player, &"rusted_sickle")
    _roll_and_hold(player, &"worn_hide")

    manager.save_character(player)

    var fresh := _make_player()
    assert_true(manager.load_character(fresh))
    var fresh_inv := InventoryComponent.of(fresh)
    assert_eq(fresh_inv.size(), 2, "both held items survive save/load")
    var first: ItemInstance = fresh_inv.items()[0]
    assert_eq(first.definition_id, held.definition_id)
    assert_eq(first.rarity, held.rarity)
    assert_eq(first.rolled_affixes.size(), held.rolled_affixes.size())
    for i in held.rolled_affixes.size():
        assert_eq(first.rolled_affixes[i].stat, held.rolled_affixes[i].stat)
        assert_almost_eq(first.rolled_affixes[i].value, held.rolled_affixes[i].value, 0.0001)

func test_inventory_survives_serialize_apply_on_a_fresh_graph():
    var played := _make_player()
    _roll_and_hold(played, &"rusted_sickle")

    var data: Dictionary = manager.serialize_character(played)
    assert_eq(typeof(data.inventory), TYPE_ARRAY)

    var fresh := _make_player()
    manager.apply_character(fresh, data)
    assert_eq(InventoryComponent.of(fresh).size(), 1)

func test_unknown_inventory_def_id_loads_sanitized_without_crash():
    var player := _make_player()
    manager.apply_character(player, {
        "inventory": [
            {"def_id": "rusted_sickle", "rarity": 1, "affixes": [{"stat": "dmg_ember", "op": 0, "value": 5.0}]},
            {"def_id": "not_a_real_item", "rarity": 1, "affixes": []},
        ],
    })
    assert_eq(InventoryComponent.of(player).size(), 1, "the unknown def_id entry is dropped at the gate")
    assert_push_warning("does not resolve")

func test_migrate_passes_a_current_version_document_through_unchanged():
    var player := _make_player()
    var data: Dictionary = manager.serialize_character(player)

    assert_eq(manager._migrate(data), data, "v1 has no migration steps yet")

func test_future_version_document_is_quarantined():
    var characters_dir := scratch_root.path_join("characters")
    DirAccess.make_dir_recursive_absolute(characters_dir)
    var path := characters_dir.path_join("default.json")
    var file := FileAccess.open(path, FileAccess.WRITE)
    file.store_string(JSON.stringify({"version": 999}, "\t"))
    file.close()

    var player := _make_player()
    var loaded: bool = manager.load_character(player)

    assert_false(loaded)
    assert_true(FileAccess.file_exists(path + ".corrupt"))

func test_malformed_document_is_sanitized_by_the_gate_with_one_warning_per_repair():
    var player := _make_player()
    manager.apply_character(player, {
        "experience": {"level": 2, "xp": 999999},
        "attributes": {"allocated": {"might": -3, "unknown_attr": 9}, "unspent": "lots"},
        "health": {"current": -5.0},
        "mana": {"current": 10.0},
        "skills": {
            "known": ["sprint", "not_a_real_skill"],
            "equipped": ["sprint", "super_jump", null, null],
        },
    })

    var xp := ExperienceComponent.of(player)
    var attributes := AttributesComponent.of(player)
    var health := HealthComponent.of(player)
    assert_eq(xp.level(), 2)
    assert_eq(xp.xp(), ExperienceComponent.xp_to_next(2) - 1, "xp must be clamped into range")
    assert_eq(attributes.allocated(StatKeys.MIGHT), 0, "a negative allocated count must clamp to 0")
    assert_eq(attributes.unspent(), 0, "a mistyped unspent must default to 0")
    assert_eq(health.current(), health.max_health(), "current <= 0 must load as a full restore")
    assert_eq(player.known_skills.size(), 1, "the unknown skill id must be dropped from known")
    assert_eq(String(player.known_skills[0].id), "sprint")
    assert_null(player.abilities.slots[1], "an equipped id missing from known must become an empty slot")
    assert_push_warning_count(6)
