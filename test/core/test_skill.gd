extends GutTest

func test_player_grantable_defaults_to_true():
    var skill := Skill.new()
    assert_true(skill.player_grantable)

func test_slime_bite_is_not_player_grantable():
    var slime_bite: Skill = load("res://skills/library/slime_bite.tres")
    assert_false(slime_bite.player_grantable)
