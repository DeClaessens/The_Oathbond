extends GutTest

func test_known_skills_resolve_by_id():
    assert_not_null(SkillCatalog.by_id(&"sprint"))
    assert_not_null(SkillCatalog.by_id(&"super_jump"))
    assert_not_null(SkillCatalog.by_id(&"spark"))
    assert_not_null(SkillCatalog.by_id(&"smite"))
    assert_not_null(SkillCatalog.by_id(&"ember_bolt"))
    assert_not_null(SkillCatalog.by_id(&"slime_bite"))

func test_unknown_id_returns_null():
    assert_null(SkillCatalog.by_id(&"not_a_real_skill"))

func test_grantable_skills_excludes_slime_bite_in_catalog_order():
    var grantable := SkillCatalog.grantable_skills()

    var ids: Array[StringName] = []
    for skill in grantable:
        assert_true(skill.player_grantable)
        ids.append(skill.id)
    assert_eq(ids, [&"sprint", &"super_jump", &"spark", &"smite", &"ember_bolt"])

func test_catalog_lists_every_skill_under_library_with_unique_non_empty_ids():
    var catalog: SkillCatalog = load(SkillCatalog.CATALOG_PATH)
    var catalog_paths := {}
    var seen_ids := {}
    for skill in catalog.skills:
        assert_not_null(skill)
        assert_ne(skill.id, &"", "every catalog entry must have a non-empty id")
        assert_false(seen_ids.has(skill.id), "duplicate id %s in catalog" % skill.id)
        seen_ids[skill.id] = true
        catalog_paths[skill.resource_path] = true

    var dir := DirAccess.open("res://skills/library")
    assert_not_null(dir)
    dir.list_dir_begin()
    var file_name := dir.get_next()
    var checked_any := false
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            checked_any = true
            var path := "res://skills/library/%s" % file_name
            assert_true(catalog_paths.has(path), "%s missing from skill_catalog.tres" % path)
        file_name = dir.get_next()
    dir.list_dir_end()
    assert_true(checked_any, "expected at least one .tres under skills/library")
