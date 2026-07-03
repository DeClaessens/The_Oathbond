class_name SkillEffect
extends Resource

## Base class for one unit of skill behavior. Subclass and override execute().
## Adding behavior = adding a subclass. Never modify Skill, AbilityComponent, or
## any character script to add new skill behavior. Effects use ONLY the
## SkillContext — they never reach into the scene tree to find their own targets.

func execute(_ctx: SkillContext) -> void:
    push_error("SkillEffect.execute() not overridden by %s" % get_class())
