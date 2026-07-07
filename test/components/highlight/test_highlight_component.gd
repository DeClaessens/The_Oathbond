extends GutTest

func _make_character() -> Node:
    var entity := Node2D.new()
    var icon := Sprite2D.new()
    icon.name = "Icon"
    entity.add_child(icon)
    var highlight := HighlightComponent.new()
    highlight.name = "HighlightComponent"
    entity.add_child(highlight)
    add_child_autofree(entity)
    return entity

func test_starts_not_highlighted():
    var entity := _make_character()
    var highlight := HighlightComponent.of(entity)
    assert_false(highlight.is_highlighted())

func test_set_highlighted_true_brightens_the_sprite():
    var entity := _make_character()
    var highlight := HighlightComponent.of(entity)
    var icon := entity.get_node(^"Icon") as Sprite2D

    highlight.set_highlighted(true)

    assert_true(highlight.is_highlighted())
    assert_ne(icon.modulate, Color.WHITE)

func test_set_highlighted_false_restores_original_modulate():
    var entity := _make_character()
    var highlight := HighlightComponent.of(entity)
    var icon := entity.get_node(^"Icon") as Sprite2D
    var original := icon.modulate

    highlight.set_highlighted(true)
    highlight.set_highlighted(false)

    assert_false(highlight.is_highlighted())
    assert_eq(icon.modulate, original)

func test_set_highlighted_is_idempotent():
    var entity := _make_character()
    var highlight := HighlightComponent.of(entity)
    var icon := entity.get_node(^"Icon") as Sprite2D
    var original := icon.modulate

    highlight.set_highlighted(true)
    var after_first_on := icon.modulate
    highlight.set_highlighted(true)

    assert_eq(icon.modulate, after_first_on, "a repeated on must not double-brighten")

    highlight.set_highlighted(false)
    assert_eq(icon.modulate, original, "double-on then off must restore the original visual state")

func test_ready_with_no_sibling_icon_does_not_crash():
    var entity := Node2D.new()
    var highlight := HighlightComponent.new()
    highlight.name = "HighlightComponent"
    entity.add_child(highlight)
    add_child_autofree(entity)

    assert_push_error("Icon")
    highlight.set_highlighted(true)
    assert_true(highlight.is_highlighted())
