extends GutTest

const SlimeScene := preload("res://entities/enemies/slime/Slime.tscn")

func test_slime_components_resolve_via_of_and_exact_names():
    var slime: CharacterBody2D = SlimeScene.instantiate()
    add_child_autofree(slime)

    assert_not_null(StatsComponent.of(slime))
    assert_not_null(FactionComponent.of(slime))
    assert_not_null(HealthComponent.of(slime))
    assert_not_null(slime.get_node_or_null(^"AbilityComponent"))
    assert_not_null(slime.get_node_or_null(^"AiControllerComponent"))
    assert_not_null(slime.get_node_or_null(^"DespawnOnDeathComponent"))
    assert_eq(FactionComponent.of(slime).faction, FactionComponent.Faction.ENEMY)

func test_slime_equips_bite_skill_on_slot_zero():
    var slime: CharacterBody2D = SlimeScene.instantiate()
    add_child_autofree(slime)

    var abilities := slime.get_node(^"AbilityComponent") as AbilityComponent
    assert_eq(abilities.slots[0].skill.id, &"slime_bite")

func test_lethal_damage_despawns_the_slime():
    var slime: CharacterBody2D = SlimeScene.instantiate()
    add_child_autofree(slime)
    HealthComponent.of(slime).apply_damage(999.0, StatKeys.DamageType.PHYSICAL, null)
    assert_true(slime.is_queued_for_deletion())
