class_name Skill
extends Resource

## Pure data: metadata + a list of composable effects. Author as .tres in the
## editor or construct in code. NEVER store runtime state here — Resources are
## shared across every character that equips them.

enum Targeting { SELF, ALLY, ENEMY, AREA, NONE }

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_multiline var description: String

@export var cooldown: float = 1.0
@export var resource_cost: int = 0
@export var targeting: Targeting = Targeting.SELF   ## declarative hint; caller resolves targets

@export var effects: Array[SkillEffect] = []
