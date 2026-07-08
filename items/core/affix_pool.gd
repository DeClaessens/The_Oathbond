class_name AffixPool
extends Resource

## An authored pool of AffixEntries, one per slot-family (weapon / armor /
## jewelry, decision 3). The ItemRoller draws distinct entries from a
## definition's pool to roll an instance's affixes.

@export var entries: Array[AffixEntry] = []
