extends Node

## Global bus for CROSS-CUTTING concerns only: floating damage numbers, audio,
## screen shake, quest tracking, analytics. If exactly one system cares about a
## signal, put it on the relevant node instead (e.g. AbilityComponent's local
## signals). Test: if you deleted Events, only genuinely cross-cutting features
## should break.

signal damage_dealt(source: Node, target: Node, amount: int, type: StringName)
signal status_applied(target: Node, status: StringName, duration: float)
signal skill_cast(caster: Node, skill: Skill)
