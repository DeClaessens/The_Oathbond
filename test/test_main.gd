extends GutTest

const MainScene := preload("res://main.tscn")

func test_camera_limits_are_copied_from_the_level_bounds_on_ready():
    var main: Node2D = MainScene.instantiate()
    add_child_autofree(main)

    var level: Level = main.get_node(^"ProvingGrounds")
    var camera: Camera2D = main.get_node(^"Player/Camera2D")

    assert_eq(camera.limit_left, int(level.bounds.position.x))
    assert_eq(camera.limit_top, int(level.bounds.position.y))
    assert_eq(camera.limit_right, int(level.bounds.end.x))
    assert_eq(camera.limit_bottom, int(level.bounds.end.y))
