extends GutTest

const DroppedItemScene := preload("res://items/dropped_item/dropped_item.tscn")

func _make_pickup() -> DroppedItem:
    var inst := ItemInstance.new()
    inst.definition_id = &"rusted_sickle"
    inst.rarity = ItemTypes.Rarity.COMMON
    var pickup: DroppedItem = DroppedItemScene.instantiate()
    pickup.setup(inst)
    add_child_autofree(pickup)
    return pickup

func _make_body_with_inventory() -> Node:
    var body := CharacterBody2D.new()
    var inv := InventoryComponent.new()
    inv.name = "InventoryComponent"
    body.add_child(inv)
    add_child_autofree(body)
    return body

func test_walking_over_a_pickup_adds_it_and_frees_the_pickup():
    var pickup := _make_pickup()
    var body := _make_body_with_inventory()
    var inv := InventoryComponent.of(body)

    pickup.body_entered.emit(body)

    assert_eq(inv.size(), 1, "the instance was added to the inventory")
    assert_same(inv.items()[0], pickup.instance)
    assert_true(pickup.is_queued_for_deletion(), "the world pickup is removed")

func test_pickup_masks_the_player_layer_only():
    var pickup := _make_pickup()
    assert_eq(pickup.collision_mask, 2, "detects the Player layer only (ADR-0008)")

func test_body_without_inventory_is_ignored():
    var pickup := _make_pickup()
    var body := CharacterBody2D.new()
    add_child_autofree(body)

    pickup.body_entered.emit(body)

    assert_false(pickup.is_queued_for_deletion(), "a body with no inventory does not consume the pickup")

func test_full_inventory_leaves_the_pickup_in_the_world():
    var pickup := _make_pickup()
    var body := _make_body_with_inventory()
    var inv := InventoryComponent.of(body)
    for i in InventoryComponent.CAPACITY:
        var filler := ItemInstance.new()
        filler.definition_id = &"rusted_sickle"
        inv.add(filler)

    pickup.body_entered.emit(body)

    assert_eq(inv.size(), InventoryComponent.CAPACITY, "add was refused at capacity")
    assert_false(pickup.is_queued_for_deletion(), "the refused pickup stays in the world")
