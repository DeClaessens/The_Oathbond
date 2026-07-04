extends GutTest

func test_super_jump_effect_composes_jump_velocity_correctly():
    var skill: Skill = load("res://skills/library/super_jump.tres")
    var effect: StatBuffEffect = skill.effects[0]

    var character := Node.new()
    var stats := StatsComponent.new()
    stats.name = "StatsComponent"
    stats.base_stats = {StatKeys.JUMP_VELOCITY: 500.0}
    character.add_child(stats)
    add_child_autofree(character)

    var ctx := SkillContext.new()
    ctx.targets = [character]
    effect.execute(ctx)

    assert_eq(stats.get_stat(StatKeys.JUMP_VELOCITY), _compose(500.0, effect.op, effect.value))

func _compose(base: float, op: StatModifier.Op, value: float) -> float:
    match op:
        StatModifier.Op.FLAT:     return base + value
        StatModifier.Op.ADD_PCT:  return base * (1.0 + value)
        StatModifier.Op.MULT_PCT: return base * (1.0 + value)
    return base
