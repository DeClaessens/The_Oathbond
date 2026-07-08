extends GutTest

const AttributesPanelScene := preload("res://ui/attributes/attributes_panel.tscn")

func _make_character() -> Node:
    var entity := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {StatKeys.MAX_HEALTH: 100.0, StatKeys.MAX_MANA: 50.0, StatKeys.CRIT_MULTI: 1.5}
    entity.add_child(stats)
    var attributes := AttributesComponent.new()
    attributes.name = "AttributesComponent"
    entity.add_child(attributes)
    add_child_autofree(entity)
    return entity

func _build() -> Array:
    var entity := _make_character()
    var panel: AttributesPanel = AttributesPanelScene.instantiate()
    add_child_autofree(panel)
    panel.bind(AttributesComponent.of(entity), StatsComponent.of(entity))
    return [panel, entity]

func test_panel_starts_hidden():
    var built := _build()
    var panel: AttributesPanel = built[0]
    assert_false(panel.is_open())

func test_toggle_action_shows_and_hides_the_panel():
    var built := _build()
    var panel: AttributesPanel = built[0]

    var press := InputEventAction.new()
    press.action = &"toggle_attributes"
    press.pressed = true
    panel._unhandled_input(press)
    assert_true(panel.is_open())

    panel._unhandled_input(press)
    assert_false(panel.is_open())

func test_bind_paints_current_allocation_and_unspent():
    var built := _build()
    var panel: AttributesPanel = built[0]

    assert_eq(panel._unspent_label.text, "Unspent points: %d" % AttributesComponent.STARTING_POINTS)
    assert_eq(panel._might_label.text, "Might: 0")
    assert_false(panel._might_button.disabled)

func test_plus_button_allocates_a_point_and_refreshes_derived_numbers():
    var built := _build()
    var panel: AttributesPanel = built[0]
    var attributes: AttributesComponent = AttributesComponent.of(built[1])

    panel._might_button.pressed.emit()

    assert_eq(attributes.allocated(StatKeys.MIGHT), 1)
    assert_eq(panel._might_label.text, "Might: 1")
    assert_true(panel._derived_label.text.contains("Max Health: 102"))

func test_unspent_points_reaching_zero_disables_the_plus_buttons():
    var built := _build()
    var panel: AttributesPanel = built[0]

    for i in AttributesComponent.STARTING_POINTS:
        panel._might_button.pressed.emit()

    assert_true(panel._might_button.disabled)
    assert_true(panel._grace_button.disabled)
    assert_true(panel._wit_button.disabled)

func test_might_row_reflects_the_get_stat_total_not_just_allocation():
    var built := _build()
    var panel: AttributesPanel = built[0]
    var attributes: AttributesComponent = AttributesComponent.of(built[1])
    var stats: StatsComponent = StatsComponent.of(built[1])
    attributes.allocate(StatKeys.MIGHT)

    # Simulate future M2.4 gear: an external FLAT +might modifier the panel
    # never allocated. The row must show allocation + gear, not the count.
    var gear := StatModifier.new()
    gear.stat = StatKeys.MIGHT
    gear.op = StatModifier.Op.FLAT
    gear.value = 4.0
    stats.add_modifier(gear)
    panel._refresh()

    assert_eq(attributes.allocated(StatKeys.MIGHT), 1)
    assert_eq(stats.get_stat(StatKeys.MIGHT), 5.0)
    assert_eq(panel._might_label.text, "Might: 5", "the row must show the get_stat total, not the allocation count")

func test_respec_button_resets_allocation_and_re_enables_buttons():
    var built := _build()
    var panel: AttributesPanel = built[0]
    for i in AttributesComponent.STARTING_POINTS:
        panel._might_button.pressed.emit()

    panel._respec_button.pressed.emit()

    assert_eq(panel._might_label.text, "Might: 0")
    assert_eq(panel._unspent_label.text, "Unspent points: %d" % AttributesComponent.STARTING_POINTS)
    assert_false(panel._might_button.disabled)
