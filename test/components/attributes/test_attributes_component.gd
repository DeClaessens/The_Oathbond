extends GutTest

func _make_character() -> Node:
    var entity := Node2D.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    entity.add_child(stats)
    var health := HealthComponent.new()
    health.name = "HealthComponent"
    entity.add_child(health)
    var mana := ManaComponent.new()
    mana.name = "ManaComponent"
    entity.add_child(mana)
    var xp := ExperienceComponent.new()
    xp.name = "ExperienceComponent"
    entity.add_child(xp)
    var attributes := AttributesComponent.new()
    attributes.name = "AttributesComponent"
    entity.add_child(attributes)
    add_child_autofree(entity)
    return entity

func test_fresh_character_starts_with_starting_points_and_zero_allocation():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)

    assert_eq(attributes.unspent(), AttributesComponent.STARTING_POINTS)
    assert_eq(attributes.allocated(StatKeys.MIGHT), 0)
    assert_eq(attributes.allocated(StatKeys.GRACE), 0)
    assert_eq(attributes.allocated(StatKeys.WIT), 0)

func test_leveling_up_grants_points_per_level():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    var xp := ExperienceComponent.of(entity)

    xp.award_xp(xp.xp_to_next(1))

    assert_eq(attributes.unspent(), AttributesComponent.STARTING_POINTS + AttributesComponent.POINTS_PER_LEVEL)

func test_allocate_spends_a_point_and_raises_the_attribute():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    var stats := StatsComponent.of(entity)

    var ok := attributes.allocate(StatKeys.MIGHT)

    assert_true(ok)
    assert_eq(attributes.unspent(), AttributesComponent.STARTING_POINTS - 1)
    assert_eq(attributes.allocated(StatKeys.MIGHT), 1)
    assert_eq(stats.get_stat(StatKeys.MIGHT), 1.0)

func test_allocate_with_no_unspent_points_fails():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    for i in AttributesComponent.STARTING_POINTS:
        attributes.allocate(StatKeys.MIGHT)

    var ok := attributes.allocate(StatKeys.MIGHT)

    assert_false(ok)
    assert_eq(attributes.unspent(), 0)
    assert_eq(attributes.allocated(StatKeys.MIGHT), AttributesComponent.STARTING_POINTS)

func test_allocate_unknown_attribute_fails():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)

    var ok := attributes.allocate(&"not_an_attribute")

    assert_false(ok)
    assert_eq(attributes.unspent(), AttributesComponent.STARTING_POINTS)

func test_might_allocation_raises_max_health_via_dependent_emission():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    var health := HealthComponent.of(entity)
    var before := health.max_health()

    attributes.allocate(StatKeys.MIGHT)

    assert_eq(health.max_health(), before + 2.0, "the cached HealthComponent max must move, proving dependent emission reaches the pool")

func test_wit_allocation_raises_max_mana_and_grace_raises_crit_multi():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    var mana := ManaComponent.of(entity)
    var stats := StatsComponent.of(entity)
    var mana_before := mana.max_mana()
    var crit_before := stats.get_stat(StatKeys.CRIT_MULTI)

    attributes.allocate(StatKeys.WIT)
    attributes.allocate(StatKeys.GRACE)

    assert_eq(mana.max_mana(), mana_before + 1.0)
    assert_almost_eq(stats.get_stat(StatKeys.CRIT_MULTI), crit_before + 0.005, 0.0001)

func test_reallocating_the_same_attribute_refreshes_rather_than_stacks():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    var stats := StatsComponent.of(entity)

    attributes.allocate(StatKeys.MIGHT)
    attributes.allocate(StatKeys.MIGHT)

    assert_eq(stats.get_stat(StatKeys.MIGHT), 2.0)
    assert_eq(stats._mods_for(StatKeys.MIGHT).size(), 1, "re-allocation must REFRESH the single keyed modifier, not stack a new one")

func test_respec_returns_every_point_and_drops_derived_bonuses():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    var health := HealthComponent.of(entity)
    var base_max := health.max_health()
    attributes.allocate(StatKeys.MIGHT)
    attributes.allocate(StatKeys.GRACE)

    attributes.respec()

    assert_eq(attributes.unspent(), AttributesComponent.STARTING_POINTS)
    assert_eq(attributes.allocated(StatKeys.MIGHT), 0)
    assert_eq(attributes.allocated(StatKeys.GRACE), 0)
    assert_eq(health.max_health(), base_max)

func test_save_state_returns_allocated_and_unspent():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    attributes.allocate(StatKeys.MIGHT)
    attributes.allocate(StatKeys.MIGHT)
    attributes.allocate(StatKeys.WIT)

    assert_eq(attributes.save_state(), {
        "allocated": {"might": 2, "grace": 0, "wit": 1},
        "unspent": AttributesComponent.STARTING_POINTS - 3,
    })

func test_load_state_sets_counts_and_replays_modifiers_without_double_applying():
    var entity := _make_character()
    var attributes := AttributesComponent.of(entity)
    var stats := StatsComponent.of(entity)

    attributes.load_state({"allocated": {"might": 3, "grace": 1, "wit": 2}, "unspent": 5})
    attributes.load_state({"allocated": {"might": 3, "grace": 1, "wit": 2}, "unspent": 5})

    assert_eq(attributes.unspent(), 5)
    assert_eq(stats.get_stat(StatKeys.MIGHT), 3.0, "loading twice must never double-apply")
    assert_eq(stats._mods_for(StatKeys.MIGHT).size(), 1)

func test_replay_equivalence_load_state_matches_allocate_to_the_same_counts():
    var played := _make_character()
    var played_attributes := AttributesComponent.of(played)
    var played_stats := StatsComponent.of(played)
    played_attributes.allocate(StatKeys.MIGHT)
    played_attributes.allocate(StatKeys.MIGHT)
    played_attributes.allocate(StatKeys.GRACE)

    var loaded := _make_character()
    var loaded_attributes := AttributesComponent.of(loaded)
    var loaded_stats := StatsComponent.of(loaded)
    loaded_attributes.load_state(played_attributes.save_state())

    assert_eq(loaded_stats.get_stat(StatKeys.MAX_HEALTH), played_stats.get_stat(StatKeys.MAX_HEALTH))
    assert_eq(loaded_attributes.save_state(), played_attributes.save_state(), "a save->load->save cycle must be a document fixed point")
