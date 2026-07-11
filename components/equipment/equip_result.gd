class_name EquipResult
extends RefCounted

## The verdict from the Equip Gate (`Equipment.validate`): `ok` plus a
## `reason` StringName the UI can surface as-is (no toast system, decision 8) --
## `&"wrong_slot"` / `&"requirements_not_met"` at M2, more later (M5 oaths).

var ok: bool
var reason: StringName

func _init(p_ok: bool = true, p_reason: StringName = &"") -> void:
    ok = p_ok
    reason = p_reason

static func success() -> EquipResult:
    return EquipResult.new(true, &"")

static func failure(reason: StringName) -> EquipResult:
    return EquipResult.new(false, reason)
