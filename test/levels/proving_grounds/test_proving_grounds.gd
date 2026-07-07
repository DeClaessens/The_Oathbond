extends GutTest

const ProvingGroundsScene := preload("res://levels/proving_grounds/proving_grounds.tscn")

const EXPECTED_BOUNDS := Rect2(0, -324, 4608, 972)

func _find_static_bodies(node: Node, out: Array) -> void:
    if node is StaticBody2D:
        out.append(node)
    for child in node.get_children():
        _find_static_bodies(child, out)

func test_root_is_a_level_with_the_contract_bounds():
    var level: Level = ProvingGroundsScene.instantiate()
    add_child_autofree(level)

    assert_true(level is Level)
    assert_eq(level.bounds, EXPECTED_BOUNDS)

func test_every_static_body_is_on_world_layer_only():
    var level: Level = ProvingGroundsScene.instantiate()
    add_child_autofree(level)

    var bodies: Array = []
    _find_static_bodies(level, bodies)
    assert_gt(bodies.size(), 0)
    for body in bodies:
        assert_eq(body.collision_layer, 1, "%s should be on layer 1 (World) only" % body.name)

func test_platforms_are_one_way_but_floor_and_walls_are_not():
    var level: Level = ProvingGroundsScene.instantiate()
    add_child_autofree(level)

    var floor_shape: CollisionShape2D = level.get_node(^"Floor/CollisionShape2D")
    var wall_left_shape: CollisionShape2D = level.get_node(^"WallLeft/CollisionShape2D")
    var wall_right_shape: CollisionShape2D = level.get_node(^"WallRight/CollisionShape2D")
    assert_false(floor_shape.one_way_collision)
    assert_false(wall_left_shape.one_way_collision)
    assert_false(wall_right_shape.one_way_collision)

    var platform_names := [&"Platform1", &"Platform2", &"Platform3", &"Platform4", &"HighLedge"]
    for platform_name in platform_names:
        var shape: CollisionShape2D = level.get_node(NodePath(str(platform_name) + "/CollisionShape2D"))
        assert_true(shape.one_way_collision, "%s should be one-way" % platform_name)
