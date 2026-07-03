class_name SkillEffect
extends Resource

func execute(_ctx: SkillContext) -> void:
    push_error("SkillEffect.execute() not overridden by %s" % get_class())
