class_name Skill
extends Resource

enum Targeting { SELF, ALLY, ENEMY, AREA, NONE }

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export_multiline var description: String

@export var cooldown: float = 1.0
@export var mana_cost: float = 0.0
@export var targeting: Targeting = Targeting.SELF
@export var targeting_range: float = 600.0
@export var ignores_global_cooldown: bool = false

@export var effects: Array[SkillEffect] = []
