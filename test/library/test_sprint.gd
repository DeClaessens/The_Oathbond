extends GutTest

func test_sprint_effect_composes_move_speed_correctly():
    var skill: Skill = load("res://skills/library/sprint.tres")
    var effect: StatBuffEffect = skill.effects[0]

    var character := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {StatKeys.MOVE_SPEED: 100.0}
    character.add_child(stats)
    add_child_autofree(character)

    var ctx := SkillContext.new()
    ctx.targets = [character]
    effect.execute(ctx)

    assert_eq(stats.get_stat(StatKeys.MOVE_SPEED), _compose(100.0, effect.op, effect.value))

func _compose(base: float, op: StatModifier.Op, value: float) -> float:
    match op:
        StatModifier.Op.FLAT:     return base + value
        StatModifier.Op.ADD_PCT:  return base * (1.0 + value)
        StatModifier.Op.MULT_PCT: return base * (1.0 + value)
    return base
