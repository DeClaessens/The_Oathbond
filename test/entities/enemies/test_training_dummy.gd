extends GutTest

const TrainingDummyScene := preload("res://entities/enemies/training_dummy/TrainingDummy.tscn")

func test_lethal_damage_despawns_the_dummy():
    var dummy: Node = TrainingDummyScene.instantiate()
    add_child_autofree(dummy)
    HealthComponent.of(dummy).apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    assert_true(dummy.is_queued_for_deletion())
