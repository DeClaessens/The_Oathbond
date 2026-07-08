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

func test_player_is_in_the_player_group():
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)

    assert_true(player.is_in_group(&"player"))

func test_save_skill_state_returns_known_and_equipped_ids():
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)

    var data := player.save_skill_state()

    assert_eq(data.known, ["sprint", "super_jump", "spark", "smite"])
    assert_eq(data.equipped, ["sprint", "super_jump", "spark", "smite"])

func test_load_skill_state_replaces_the_authored_default_kit():
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)

    player.load_skill_state({
        "known": ["spark"],
        "equipped": ["spark", null, null, null],
    })

    assert_eq(player.known_skills.size(), 1)
    assert_eq(String(player.known_skills[0].id), "spark")
    assert_eq(String(player.abilities.slots[0].skill.id), "spark")
    assert_null(player.abilities.slots[1])
    assert_null(player.abilities.slots[2])
    assert_null(player.abilities.slots[3])

func test_load_skill_state_drops_unknown_ids():
    var player: Player = PlayerScene.instantiate()
    add_child_autofree(player)

    player.load_skill_state({"known": ["not_a_real_skill"], "equipped": [null, null, null, null]})

    assert_eq(player.known_skills.size(), 0)
