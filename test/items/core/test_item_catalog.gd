extends GutTest

func test_known_definitions_resolve_by_id():
    assert_not_null(ItemCatalog.by_id(&"rusted_sickle"))
    assert_not_null(ItemCatalog.by_id(&"worn_hide"))

func test_unknown_id_returns_null():
    assert_null(ItemCatalog.by_id(&"not_a_real_item"))

func test_catalog_lists_every_definition_under_library_with_unique_non_empty_ids():
    var catalog: ItemCatalog = load(ItemCatalog.CATALOG_PATH)
    var catalog_paths := {}
    var seen_ids := {}
    for item in catalog.items:
        assert_not_null(item)
        assert_ne(item.id, &"", "every catalog entry must have a non-empty id")
        assert_false(seen_ids.has(item.id), "duplicate id %s in catalog" % item.id)
        seen_ids[item.id] = true
        catalog_paths[item.resource_path] = true

    var dir := DirAccess.open("res://items/library")
    assert_not_null(dir)
    dir.list_dir_begin()
    var file_name := dir.get_next()
    var checked_any := false
    while file_name != "":
        if not dir.current_is_dir() and file_name.ends_with(".tres"):
            checked_any = true
            var path := "res://items/library/%s" % file_name
            assert_true(catalog_paths.has(path), "%s missing from item_catalog.tres" % path)
        file_name = dir.get_next()
    dir.list_dir_end()
    assert_true(checked_any, "expected at least one .tres under items/library")
