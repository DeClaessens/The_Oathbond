extends GutTest

const PlayerScene := preload("res://entities/player/Player.tscn")

func test_player_has_a_smoothed_camera_with_smoothed_limits():
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)

    var camera: Camera2D = player.get_node_or_null(^"Camera2D")
    assert_not_null(camera)
    assert_true(camera.position_smoothing_enabled)
    assert_true(camera.limit_smoothed)

func test_camera_updates_on_the_physics_tick():
    # Smoothing in the idle callback chases the physics-driven player between
    # ticks, oscillating the player on screen (the M0.8 stutter bug).
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)

    var camera: Camera2D = player.get_node(^"Camera2D")
    assert_eq(camera.process_callback, Camera2D.CAMERA2D_PROCESS_PHYSICS)
