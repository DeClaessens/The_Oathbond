extends GutTest

func test_play_sets_label_text_to_the_damage_amount():
    var instance: FloatingCombatText = preload("res://vfx/floating_combat_text/floating_combat_text.tscn").instantiate()
    add_child_autofree(instance)
    instance.play(42)
    assert_eq(instance.get_node("Label").text, "42")
