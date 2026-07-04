extends GutTest

## CooldownWedge's fraction clamp — _draw()'s geometry is not asserted, same
## as the rest of the Skill Bar's rendering.

func test_set_fraction_stores_the_value():
    var wedge := CooldownWedge.new()
    add_child_autofree(wedge)
    wedge.set_fraction(0.5)
    assert_eq(wedge.fraction(), 0.5)

func test_set_fraction_clamps_above_one():
    var wedge := CooldownWedge.new()
    add_child_autofree(wedge)
    wedge.set_fraction(1.5)
    assert_eq(wedge.fraction(), 1.0)

func test_set_fraction_clamps_below_zero():
    var wedge := CooldownWedge.new()
    add_child_autofree(wedge)
    wedge.set_fraction(-0.5)
    assert_eq(wedge.fraction(), 0.0)
