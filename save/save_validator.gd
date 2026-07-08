class_name SaveValidator
extends RefCounted

## The Save Gate (ADR-0015): every character document, regardless of where
## it came from, passes through validate_character before any load_state
## runs. Sanitizes rather than rejects -- unknown skill ids are dropped,
## equipped ids not in known become empty slots, numbers are clamped to
## legal ranges, and each repair emits a push_warning naming the field.

## Current character-document schema version. Lives here rather than on
## SaveManager because the autoload has no class_name to reference it by.
const VERSION := 1

static func validate_character(data: Dictionary) -> Dictionary:
    var src: Dictionary = data if typeof(data) == TYPE_DICTIONARY else {}
    var out := {
        "version": VERSION,
        "id": String(src.get("id", "default")),
    }
    out["experience"] = _validate_experience(src.get("experience"))
    out["attributes"] = _validate_attributes(src.get("attributes"))
    out["health"] = _validate_pool(src.get("health"), "health")
    out["mana"] = _validate_pool(src.get("mana"), "mana")
    out["skills"] = _validate_skills(src.get("skills"))
    return out

static func _validate_experience(section) -> Dictionary:
    var src: Dictionary = section if typeof(section) == TYPE_DICTIONARY else {}
    if typeof(section) != TYPE_DICTIONARY:
        push_warning("SaveValidator: missing/invalid experience section, using defaults")

    var level_raw = src.get("level", 1)
    var level: int
    if _is_numeric(level_raw):
        level = int(level_raw)
    else:
        push_warning("SaveValidator: experience.level is not numeric, defaulting to 1")
        level = 1
    if level < 1:
        push_warning("SaveValidator: experience.level %s out of range, clamped to 1" % str(level_raw))
        level = 1

    var xp_raw = src.get("xp", 0)
    var xp: int
    if _is_numeric(xp_raw):
        xp = int(xp_raw)
    else:
        push_warning("SaveValidator: experience.xp is not numeric, defaulting to 0")
        xp = 0
    var xp_ceiling := ExperienceComponent.xp_to_next(level) - 1
    var clamped_xp := clampi(xp, 0, xp_ceiling)
    if clamped_xp != xp:
        push_warning("SaveValidator: experience.xp %d out of range, clamped to %d" % [xp, clamped_xp])

    return {"level": level, "xp": clamped_xp}

## Additive optional section (M2.2, ADR-0016's first consumer): a v1
## document written before this story lacked "attributes" entirely, so a
## missing section validates silently to the zero allocation -- only a
## *present but malformed* section warns, unlike experience/health/skills
## which are core sections that warn on absence too.
static func _validate_attributes(section) -> Dictionary:
    var known_attrs: Array[StringName] = [StatKeys.MIGHT, StatKeys.GRACE, StatKeys.WIT]
    var zero_allocation := {}
    for attr in known_attrs:
        zero_allocation[String(attr)] = 0

    if typeof(section) != TYPE_DICTIONARY:
        if section != null:
            push_warning("SaveValidator: invalid attributes section, using defaults")
        return {"allocated": zero_allocation, "unspent": 0}

    var src: Dictionary = section

    var allocated_value = src.get("allocated", {})
    var allocated_src: Dictionary = allocated_value if typeof(allocated_value) == TYPE_DICTIONARY else {}
    if typeof(allocated_value) != TYPE_DICTIONARY:
        push_warning("SaveValidator: attributes.allocated is not a dictionary, defaulting to zero allocation")

    var allocated := {}
    for attr in known_attrs:
        var raw = allocated_src.get(String(attr), 0)
        var count: int
        if _is_numeric(raw):
            count = int(raw)
        else:
            push_warning("SaveValidator: attributes.allocated.%s is not numeric, defaulting to 0" % String(attr))
            count = 0
        if count < 0:
            push_warning("SaveValidator: attributes.allocated.%s %d is negative, clamped to 0" % [String(attr), count])
            count = 0
        allocated[String(attr)] = count

    for key in allocated_src.keys():
        if not known_attrs.has(StringName(key)):
            push_warning("SaveValidator: attributes.allocated has unknown key %s, dropped" % str(key))

    var unspent_raw = src.get("unspent", 0)
    var unspent: int
    if _is_numeric(unspent_raw):
        unspent = int(unspent_raw)
    else:
        push_warning("SaveValidator: attributes.unspent is not numeric, defaulting to 0")
        unspent = 0
    if unspent < 0:
        push_warning("SaveValidator: attributes.unspent %d is negative, clamped to 0" % unspent)
        unspent = 0

    return {"allocated": allocated, "unspent": unspent}

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

    var known_value = src.get("known", [])
    if not known_value is Array:
        push_warning("SaveValidator: skills.known is not an array, defaulting to empty")
        known_value = []
    var known_raw: Array = known_value
    var known: Array = []
    for id in known_raw:
        if _is_skill_id(id) and SkillCatalog.by_id(StringName(id)) != null:
            known.append(String(id))
        else:
            push_warning("SaveValidator: skills.known id %s does not resolve, dropped" % str(id))

    var equipped_value = src.get("equipped", [])
    if not equipped_value is Array:
        push_warning("SaveValidator: skills.equipped is not an array, defaulting to empty")
        equipped_value = []
    var equipped_raw: Array = equipped_value
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
