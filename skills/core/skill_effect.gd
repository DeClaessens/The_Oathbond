class_name SkillEffect
extends Resource

## Returns true on success. A false return tells AbilityComponent the skill
## activation failed: no cooldown is applied and skill_failed is emitted
## instead of skill_activated.
func execute(_ctx: SkillContext) -> bool:
    push_error("SkillEffect.execute() not overridden by %s" % get_class())
    return false
