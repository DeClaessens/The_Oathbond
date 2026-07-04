extends GutTest

const HealthBarScene := preload("res://components/health/health_bar.tscn")

func _build() -> HealthBar:
    var bar: HealthBar = HealthBarScene.instantiate()
    add_child_autofree(bar)
    return bar

func test_hidden_at_full_health_after_ready():
    var bar := _build()
    assert_false(bar.visible)

func test_becomes_visible_when_damaged():
    var bar := _build()
    bar._on_health_changed(70.0, 100.0)
    assert_true(bar.visible)

func test_returns_to_hidden_at_full_health():
    var bar := _build()
    bar._on_health_changed(70.0, 100.0)
    bar._on_health_changed(100.0, 100.0)
    assert_false(bar.visible, "bar must hide again once health returns to max")

func test_fill_width_scales_with_fraction():
    assert_eq(HealthBar.fill_width(0.5, 48.0), 24.0)
    assert_eq(HealthBar.fill_width(0.0, 48.0), 0.0)
    assert_eq(HealthBar.fill_width(1.0, 48.0), 48.0)

func test_fill_width_clamps_out_of_range_fractions():
    assert_eq(HealthBar.fill_width(-1.0, 48.0), 0.0)
    assert_eq(HealthBar.fill_width(2.0, 48.0), 48.0)

func test_bind_rebinding_to_a_new_health_component_does_not_double_update():
    var bar := _build()
    var health_a: HealthComponent = autofree(HealthComponent.new())
    var health_b: HealthComponent = autofree(HealthComponent.new())

    bar.bind(health_a)
    bar.bind(health_b)

    watch_signals(bar)
    health_a.health_changed.emit(50.0, 100.0)
    assert_false(bar.visible, "the old health component must be disconnected after rebind")

    health_b.health_changed.emit(50.0, 100.0)
    assert_true(bar.visible, "the newly bound health component must still drive the bar")
