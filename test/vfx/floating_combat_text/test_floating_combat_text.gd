extends GutTest

func test_play_sets_label_text_to_the_damage_amount():
    var instance: FloatingCombatText = preload("res://vfx/floating_combat_text/floating_combat_text.tscn").instantiate()
    add_child_autofree(instance)
    instance.play(42)
    assert_eq(instance.get_node("Label").text, "42")

func test_play_normal_hit_uses_default_scale_and_color():
    var instance: FloatingCombatText = preload("res://vfx/floating_combat_text/floating_combat_text.tscn").instantiate()
    add_child_autofree(instance)
    instance.play(42, false)
    assert_eq(instance.scale, Vector2.ONE)
    assert_eq(instance.get_node("Label").modulate, Color.WHITE)

func test_play_crit_renders_larger_and_with_the_crit_color():
    var instance: FloatingCombatText = preload("res://vfx/floating_combat_text/floating_combat_text.tscn").instantiate()
    add_child_autofree(instance)
    instance.play(80, true)
    assert_eq(instance.scale, Vector2.ONE * FloatingCombatText.CRIT_SCALE)
    assert_eq(instance.get_node("Label").modulate, FloatingCombatText.CRIT_COLOR)
