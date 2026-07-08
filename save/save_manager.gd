extends Node

## Persists one character (M1: exactly one, id "default") to
## user://saves/characters/<id>.json plus the account roster in
## user://saves/account.json (ADR-0015). Composes the per-component
## save_state()/load_state() sections; components own their own data.
##
## Serialization is split pure-from-I/O: serialize_character/apply_character
## touch no disk, so most tests never need a scratch filesystem.

const CHARACTER_ID := &"default"

## Plain var, not a const -- tests point this at a scratch directory.
var save_root := "user://saves/"

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        var player := get_tree().get_first_node_in_group(&"player")
        if player != null:
            save_character(player)

func serialize_character(player: Node) -> Dictionary:
    var experience := ExperienceComponent.of(player)
    var health := HealthComponent.of(player)
    var mana := ManaComponent.of(player)
    var inventory := InventoryComponent.of(player)
    return {
        "version": SaveValidator.VERSION,
        "id": String(CHARACTER_ID),
        "experience": experience.save_state() if experience != null else {},
        "health": health.save_state() if health != null else {},
        "mana": mana.save_state() if mana != null else {},
        "skills": player.save_skill_state() if player.has_method("save_skill_state") else {},
        "inventory": inventory.save_state() if inventory != null else [],
    }

## Load order is fixed -- experience, then health, then mana, then skills
## (ADR-0015): growth modifiers raise max pools via stat_changed before the
## pools clamp their persisted currents.
func apply_character(player: Node, data: Dictionary) -> void:
    var sanitized := SaveValidator.validate_character(data)

    var experience := ExperienceComponent.of(player)
    if experience != null:
        experience.load_state(sanitized.experience)

    var health := HealthComponent.of(player)
    if health != null:
        health.load_state(sanitized.health)

    var mana := ManaComponent.of(player)
    if mana != null:
        mana.load_state(sanitized.mana)

    if player.has_method("load_skill_state"):
        player.load_skill_state(sanitized.skills)

    var inventory := InventoryComponent.of(player)
    if inventory != null:
        inventory.load_state(sanitized.inventory)

func save_character(player: Node) -> void:
    var data := serialize_character(player)
    var characters_dir := save_root.path_join("characters")
    DirAccess.make_dir_recursive_absolute(characters_dir)
    var path := characters_dir.path_join("%s.json" % String(CHARACTER_ID))
    var file := FileAccess.open(path, FileAccess.WRITE)
    if file == null:
        push_error("SaveManager.save_character: failed to open %s for writing" % path)
        return
    file.store_string(JSON.stringify(data, "\t"))
    file.close()
    _add_to_roster(CHARACTER_ID)

## Returns false (and leaves the scene's authored defaults untouched) when
## no save file exists. An unparseable or too-new document is quarantined
## as <name>.json.corrupt and also returns false -- never silently deleted.
func load_character(player: Node) -> bool:
    var path := _character_path(CHARACTER_ID)
    if not FileAccess.file_exists(path):
        return false

    var file := FileAccess.open(path, FileAccess.READ)
    var text := file.get_as_text()
    file.close()

    var parsed = JSON.parse_string(text)
    if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) > SaveValidator.VERSION:
        _quarantine(path)
        return false

    apply_character(player, _migrate(parsed))
    return true

## The migration seam (ADR-0015): upgrades an old document one version
## step at a time before it reaches the Save Gate. v1 is the first schema,
## so there are no steps yet -- a future v2 adds its step here.
func _migrate(data: Dictionary) -> Dictionary:
    return data

func delete_character(id: StringName) -> void:
    var path := _character_path(id)
    if FileAccess.file_exists(path):
        DirAccess.remove_absolute(path)
    _remove_from_roster(id)

func _character_path(id: StringName) -> String:
    return save_root.path_join("characters").path_join("%s.json" % String(id))

func _account_path() -> String:
    return save_root.path_join("account.json")

func _load_account() -> Dictionary:
    var path := _account_path()
    if FileAccess.file_exists(path):
        var file := FileAccess.open(path, FileAccess.READ)
        var text := file.get_as_text()
        file.close()
        var parsed = JSON.parse_string(text)
        if typeof(parsed) == TYPE_DICTIONARY:
            return parsed
    return {"version": SaveValidator.VERSION, "characters": []}

func _save_account(account: Dictionary) -> void:
    DirAccess.make_dir_recursive_absolute(save_root)
    var file := FileAccess.open(_account_path(), FileAccess.WRITE)
    if file == null:
        push_error("SaveManager: failed to open account file for writing")
        return
    file.store_string(JSON.stringify(account, "\t"))
    file.close()

func _add_to_roster(id: StringName) -> void:
    var account := _load_account()
    var characters: Array = account.get("characters", [])
    if not characters.has(String(id)):
        characters.append(String(id))
    account["characters"] = characters
    account["version"] = SaveValidator.VERSION
    _save_account(account)

func _remove_from_roster(id: StringName) -> void:
    var account := _load_account()
    var characters: Array = account.get("characters", [])
    characters.erase(String(id))
    account["characters"] = characters
    account["version"] = SaveValidator.VERSION
    _save_account(account)

func _quarantine(path: String) -> void:
    var corrupt_path := path + ".corrupt"
    if FileAccess.file_exists(corrupt_path):
        DirAccess.remove_absolute(corrupt_path)
    DirAccess.rename_absolute(path, corrupt_path)
    push_warning("SaveManager: %s could not be loaded, quarantined as %s" % [path, corrupt_path])
