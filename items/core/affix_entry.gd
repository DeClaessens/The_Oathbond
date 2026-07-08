class_name AffixEntry
extends Resource

## One authored affix in an AffixPool: a stat, an op, and a [min_value,
## max_value] range the ItemRoller draws a value from. Also authored directly
## on a definition's implicit_mods with min_value == max_value to denote a
## fixed mod (a Sickle's base damage).

@export var stat: StringName = &""
@export var op: StatModifier.Op = StatModifier.Op.FLAT
@export var min_value: float = 0.0
@export var max_value: float = 0.0
