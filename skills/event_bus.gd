extends Node

signal damage_dealt(source: Node, target: Node, amount: int, type: StatKeys.DamageType)
signal status_applied(target: Node, status: StringName, duration: float)
signal skill_cast(caster: Node, skill: Skill)
