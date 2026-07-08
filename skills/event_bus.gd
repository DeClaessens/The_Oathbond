extends Node

signal damage_dealt(source: Node, target: Node, amount: int, type: StatKeys.DamageType, is_crit: bool)
signal character_died(victim: Node, killer: Node)
signal status_applied(target: Node, status: StringName, duration: float)
signal skill_cast(caster: Node, skill: Skill)
