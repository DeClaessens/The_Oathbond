class_name SkillContext
extends RefCounted

## Carrier passed to every effect on activation. Everything an effect needs must
## be in here. caster_stats is resolved ONCE by AbilityComponent so effects never
## look it up themselves.

var caster: Node
var caster_stats: StatsComponent           ## resolved by AbilityComponent
var targets: Array[Node] = []
var source_position: Vector2
var aim_direction: Vector2                  ## directional/projectile skills
