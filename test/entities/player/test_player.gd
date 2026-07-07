extends GutTest

const PlayerScene := preload("res://entities/player/Player.tscn")

func test_player_has_a_smoothed_camera_with_smoothed_limits():
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)

    var camera: Camera2D = player.get_node_or_null(^"Camera2D")
    assert_not_null(camera)
    assert_true(camera.position_smoothing_enabled)
    assert_true(camera.limit_smoothed)
