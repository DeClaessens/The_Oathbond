extends GutTest

## The victim owns the LootComponent; the drop spawns into the victim's parent
## as a DroppedItem when the killer carries an InventoryComponent.

var world: Node2D
var victim: Node2D
var loot: LootComponent

func before_each():
    world = Node2D.new()
    add_child_autofree(world)
    victim = Node2D.new()
    world.add_child(victim)
    loot = LootComponent.new()
    loot.drop_table = [ItemCatalog.by_id(&"rusted_sickle")]
    loot.drop_chance = 1.0
    victim.add_child(loot)

func _make_killer_with_inventory() -> Node:
    var killer := Node.new()
    var inv := InventoryComponent.new()
    inv.name = "InventoryComponent"
    killer.add_child(inv)
    add_child_autofree(killer)
    return killer

func _dropped_items() -> Array:
    var out: Array = []
    for child in world.get_children():
        if child is DroppedItem:
            out.append(child)
    return out

func test_death_to_an_inventory_carrier_spawns_a_world_pickup():
    var killer := _make_killer_with_inventory()
    Events.character_died.emit(victim, killer)
    var drops := _dropped_items()
    assert_eq(drops.size(), 1, "one pickup spawned into the victim's parent")
    assert_not_null(drops[0].instance, "the pickup carries a rolled instance")
    assert_eq(drops[0].instance.definition_id, &"rusted_sickle")

func test_pickup_spawns_at_the_victim_position():
    victim.global_position = Vector2(321, 654)
    var killer := _make_killer_with_inventory()
    Events.character_died.emit(victim, killer)
    var drops := _dropped_items()
    assert_eq(drops.size(), 1)
    assert_eq(drops[0].global_position, Vector2(321, 654))

func test_killer_without_inventory_drops_nothing():
    var killer := Node.new()
    add_child_autofree(killer)
    Events.character_died.emit(victim, killer)
    assert_eq(_dropped_items().size(), 0)

func test_drop_chance_zero_drops_nothing():
    loot.drop_chance = 0.0
    var killer := _make_killer_with_inventory()
    Events.character_died.emit(victim, killer)
    assert_eq(_dropped_items().size(), 0)

func test_only_reacts_to_its_own_parents_death():
    var other := Node2D.new()
    world.add_child(other)
    var killer := _make_killer_with_inventory()
    Events.character_died.emit(other, killer)
    assert_eq(_dropped_items().size(), 0, "a different victim's death must not trigger this loot")

func test_empty_drop_table_drops_nothing():
    loot.drop_table = []
    var killer := _make_killer_with_inventory()
    Events.character_died.emit(victim, killer)
    assert_eq(_dropped_items().size(), 0)
