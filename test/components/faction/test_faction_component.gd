extends GutTest

func test_default_faction_is_neutral():
    var faction := FactionComponent.new()
    assert_eq(faction.faction, FactionComponent.Faction.NEUTRAL)
    faction.free()

func test_of_resolves_the_fixed_child_name():
    var owner := Node.new()
    add_child_autofree(owner)
    var faction := FactionComponent.new()
    faction.name = "FactionComponent"
    faction.faction = FactionComponent.Faction.ENEMY
    owner.add_child(faction)

    var resolved := FactionComponent.of(owner)
    assert_eq(resolved, faction)
    assert_eq(resolved.faction, FactionComponent.Faction.ENEMY)

func test_of_returns_null_without_a_faction_component():
    var owner := Node.new()
    add_child_autofree(owner)
    assert_null(FactionComponent.of(owner))

func test_of_returns_null_for_null_node():
    assert_null(FactionComponent.of(null))
