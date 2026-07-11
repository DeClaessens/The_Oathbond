class_name SkillCatalog
extends Resource

## Authored id -> Skill registry (res://skills/skill_catalog.tres): the only
## legal way to resolve a persisted Skill.id (ADR-0015), since save data
## never stores resource paths. Every Skill under skills/library/ must be
## listed here, enemy skills included -- one completeness rule, no
## exceptions to remember.

const CATALOG_PATH := "res://skills/skill_catalog.tres"

@export var skills: Array[Skill] = []

static var _by_id: Dictionary = {}
static var _loaded: bool = false

## Loads the authored catalog once (lazy static Dictionary) and resolves a
## persisted Skill.id, or null if the id is unknown. Duplicate or empty ids
## in the catalog are authoring errors, surfaced with push_error.
static func by_id(id: StringName) -> Skill:
    _ensure_loaded()
    return _by_id.get(id)

## Player-facing skill library for UI (e.g. the Skills Window): every catalog
## skill with player_grantable == true, in authored catalog order. Filters the
## view only -- slime_bite and every other skill stay listed in the catalog.
static func grantable_skills() -> Array[Skill]:
    var catalog: SkillCatalog = load(CATALOG_PATH)
    var result: Array[Skill] = []
    if catalog == null:
        return result
    for skill in catalog.skills:
        if skill != null and skill.player_grantable:
            result.append(skill)
    return result

static func _ensure_loaded() -> void:
    if _loaded:
        return
    _loaded = true
    var catalog: SkillCatalog = load(CATALOG_PATH)
    if catalog == null:
        push_error("SkillCatalog: failed to load %s" % CATALOG_PATH)
        return
    for skill in catalog.skills:
        if skill == null:
            continue
        if skill.id == &"":
            push_error("SkillCatalog: skill asset %s has an empty id" % skill.resource_path)
            continue
        if _by_id.has(skill.id):
            push_error("SkillCatalog: duplicate skill id %s" % skill.id)
            continue
        _by_id[skill.id] = skill
