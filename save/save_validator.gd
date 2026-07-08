class_name SaveValidator
extends RefCounted

## The Save Gate (ADR-0015): every character document, regardless of where
## it came from, passes through validate_character before any load_state
## runs. Sanitizes rather than rejects -- unknown skill ids are dropped,
## equipped ids not in known become empty slots, numbers are clamped to
## legal ranges, and each repair emits a push_warning naming the field.

static func validate_character(data: Dictionary) -> Dictionary:
    var src: Dictionary = data if typeof(data) == TYPE_DICTIONARY else {}
    var out := {
        "version": 1,
        "id": String(src.get("id", "default")),
    }
    out["experience"] = _validate_experience(src.get("experience"))
    out["health"] = _validate_pool(src.get("health"), "health")
    out["mana"] = _validate_pool(src.get("mana"), "mana")
    out["skills"] = _validate_skills(src.get("skills"))
    return out

static func _validate_experience(section) -> Dictionary:
    var src: Dictionary = section if typeof(section) == TYPE_DICTIONARY else {}
    if typeof(section) != TYPE_DICTIONARY:
        push_warning("SaveValidator: missing/invalid experience section, using defaults")

    var level_raw = src.get("level", 1)
    var level: int = int(level_raw) if _is_numeric(level_raw) else 1
    if level < 1:
        push_warning("SaveValidator: experience.level %s out of range, clamped to 1" % str(level_raw))
        level = 1

    var xp_raw = src.get("xp", 0)
    var xp: int = int(xp_raw) if _is_numeric(xp_raw) else 0
    var xp_ceiling := ExperienceComponent.xp_to_next(level) - 1
    var clamped_xp := clampi(xp, 0, xp_ceiling)
    if clamped_xp != xp:
        push_warning("SaveValidator: experience.xp %d out of range, clamped to %d" % [xp, clamped_xp])

    return {"level": level, "xp": clamped_xp}

static func _validate_pool(section, field: String) -> Dictionary:
    var src: Dictionary = section if typeof(section) == TYPE_DICTIONARY else {}
    if typeof(section) != TYPE_DICTIONARY:
        push_warning("SaveValidator: missing/invalid %s section, using defaults" % field)

    var current_raw = src.get("current", 0.0)
    var current: float
    if _is_numeric(current_raw):
        current = float(current_raw)
    else:
        push_warning("SaveValidator: %s.current is not numeric, defaulting to 0.0" % field)
        current = 0.0
    return {"current": current}

static func _validate_skills(section) -> Dictionary:
    var src: Dictionary = section if typeof(section) == TYPE_DICTIONARY else {}
    if typeof(section) != TYPE_DICTIONARY:
        push_warning("SaveValidator: missing/invalid skills section, using defaults")

    var known_raw: Array = src.get("known") if src.get("known") is Array else []
    var known: Array = []
    for id in known_raw:
        if _is_skill_id(id) and SkillCatalog.by_id(StringName(id)) != null:
            known.append(String(id))
        else:
            push_warning("SaveValidator: skills.known id %s does not resolve, dropped" % str(id))

    var equipped_raw: Array = src.get("equipped") if src.get("equipped") is Array else []
    var equipped: Array = []
    for i in AbilityComponent.SLOT_COUNT:
        var id = equipped_raw[i] if i < equipped_raw.size() else null
        if id == null:
            equipped.append(null)
        elif _is_skill_id(id) and known.has(String(id)):
            equipped.append(String(id))
        else:
            push_warning("SaveValidator: skills.equipped[%d] id %s not in known, cleared" % [i, str(id)])
            equipped.append(null)

    return {"known": known, "equipped": equipped}

static func _is_numeric(value) -> bool:
    return typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT

static func _is_skill_id(value) -> bool:
    return typeof(value) == TYPE_STRING or typeof(value) == TYPE_STRING_NAME
