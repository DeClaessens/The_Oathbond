class_name SkillEffect
extends Resource

func execute(_ctx: SkillContext) -> bool:
    push_error("SkillEffect.execute() not overridden by %s" % get_class())
    return false
