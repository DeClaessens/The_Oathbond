extends SceneTree

var _frame := 0

func _process(_delta: float) -> bool:
    _frame += 1
    if _frame == 3:
        _run()
        return true
    return false

func _run() -> void:
    var player_scene: PackedScene = load("res://entities/player/Player.tscn")
    var player: Node = player_scene.instantiate()
    root.add_child(player)
    current_scene = player

    var mana: ManaComponent = ManaComponent.of(player)
    var bar: ManaBar = mana.get_node("ManaBar")
    var health_bar := player.get_node("HealthComponent/HealthBar")

    print("=== Scene wiring ===")
    print("ManaComponent found: %s" % [mana != null])
    print("mana max=%s current=%s fraction=%s" % [mana.max_mana(), mana.current(), mana.fraction()])
    print("ManaBar position=%s visible=%s" % [bar.position, bar.visible])
    print("ManaBar BACKGROUND=%s FOREGROUND=%s" % [ManaBar.BACKGROUND, ManaBar.FOREGROUND])
    print("HealthBar position=%s visible=%s" % [health_bar.position, health_bar.visible])
    print("Vertical gap (health.y - mana.y) = %s (expect 8)" % [bar.position.y - health_bar.position.y])

    var abilities: AbilityComponent = player.abilities
    print("\n=== Gating: repeated Fireball casts (slot 2, mana_cost=20), cooldown forced to 0 each time ===")
    for i in range(7):
        abilities.slots[2].cooldown_remaining = 0.0
        var before := mana.current()
        var events := []
        var on_failed := func(idx, reason): events.append(["failed", reason])
        var on_activated := func(idx, s): events.append(["activated"])
        abilities.skill_failed.connect(on_failed)
        abilities.skill_activated.connect(on_activated)
        abilities.activate(2, player.global_position + Vector2.RIGHT * 100)
        abilities.skill_failed.disconnect(on_failed)
        abilities.skill_activated.disconnect(on_activated)
        print("cast %d: before=%s after=%s events=%s" % [i + 1, before, mana.current(), events])

    print("\n=== Regen: simulating 1s of ticks ===")
    var before_regen := mana.current()
    for i in range(60):
        mana._process(1.0 / 60.0)
    print("mana after ~1s regen: %s (was %s)" % [mana.current(), before_regen])

    print("\n=== Retry cast now that mana regenerated ===")
    abilities.slots[2].cooldown_remaining = 0.0
    var before2 := mana.current()
    abilities.activate(2, player.global_position + Vector2.RIGHT * 100)
    print("cast after regen: before=%s after=%s" % [before2, mana.current()])

    quit()
