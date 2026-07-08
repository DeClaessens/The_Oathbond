# M1-02 — Character save/load

*Depends on M0 complete (merged). Closes Epic M1: quit and resume a character.*

## Goal

Quit the game and resume the same character: level, XP, current health and
mana, and known/equipped skills come back exactly. The account file exists
alongside from day one — empty of meaning until Bonds (M6), but its
existence is VISION structural decision 1 made real. The architecture is
decided in **ADR-0015** (read it first); this brief turns it into files,
classes, and tests.

## Design decisions (made — do not reopen)

1. **`SaveManager` autoload** at `save/save_manager.gd`, registered in
   `project.godot` as `SaveManager` (after `Events`). Like `event_bus.gd` it
   has **no `class_name`** (autoload name and class_name may not collide).
   Public surface:
   - `save_character(player: Node) -> void` — serialize + write
     `user://saves/characters/default.json`, and create/update
     `user://saves/account.json` (roster contains `"default"`).
   - `load_character(player: Node) -> bool` — read, migrate, validate,
     apply; `false` when no file exists (fresh character keeps the scene's
     authored defaults).
   - `delete_character(id: StringName) -> void` — removes the character
     file and its roster entry; the account file remains.
   - `var save_root := "user://saves/"` — plain var so tests point it at a
     scratch directory.
   Serialization is split pure-from-I/O: `serialize_character(player) ->
   Dictionary` and `apply_character(player, data)` do no file access, so
   most tests never touch disk.
2. **Document schemas (version 1).** Character file:
   ```json
   {
     "version": 1,
     "id": "default",
     "experience": {"level": 3, "xp": 12},
     "health": {"current": 57.0},
     "mana": {"current": 20.0},
     "skills": {
       "known": ["sprint", "super_jump", "spark", "smite"],
       "equipped": ["sprint", "super_jump", "spark", "smite"]
     }
   }
   ```
   `skills.equipped` always has exactly `AbilityComponent.SLOT_COUNT`
   entries; an empty slot is `null`. Account file:
   `{"version": 1, "characters": ["default"]}`. Written with
   `JSON.stringify(data, "\t")`.
3. **Component contract:** `save_state() -> Dictionary` and
   `load_state(data: Dictionary) -> void` added to `ExperienceComponent`,
   `HealthComponent`, `ManaComponent`. `SaveManager` finds them via the
   existing `X.of()` helpers and owns the envelope; components own only
   their own section (ADR-0015 decision 3). Skills are Player-level state:
   `Player.save_skill_state()` / `Player.load_skill_state(data)` handle
   `known_skills` and slot equips by id.
4. **Growth replay, not growth serialization** (the ADR-0015 hazard).
   Split `ExperienceComponent._apply_level_up_growth()` into
   `_apply_growth_modifiers()` (the two `StatModifier`s only) and the
   full-restore part. `load_state` sets `_level`/`_xp`, then calls
   `_apply_growth_modifiers()` once per level above 1, then emits
   `experience_changed` — it never calls `restore_full()`. `award_xp`'s
   behavior is unchanged (growth + full restore on level-up).
5. **Load order is fixed:** experience → health → mana → skills
   (ADR-0015 consequence: growth modifiers must raise max pools via
   `stat_changed` before pools clamp their persisted currents).
6. **Pool semantics on load.** `HealthComponent.load_state({current})`:
   if `current <= 0.0` → `restore_full()` (never resume dead); otherwise
   `_current = clampf(current, 0.0, _max)`, `_dead = false`, emit
   `health_changed`. `ManaComponent.load_state`: clamp to `[0, _max]`,
   emit `mana_changed`. `_max` and `_dead` are never persisted.
7. **`SkillCatalog`** — `skills/core/skill_catalog.gd`
   (`class_name SkillCatalog extends Resource`) with
   `@export var skills: Array[Skill]`, plus the authored instance
   `skills/skill_catalog.tres` listing **every** `.tres` under
   `skills/library/` (enemy skills included — one completeness rule, no
   exceptions to remember). A static `SkillCatalog.by_id(id: StringName)
   -> Skill` loads the catalog once (lazy static Dictionary) and
   `push_error`s duplicate or empty ids. Verify every library asset
   actually has a unique non-empty `id` — fixing a missing one (in-editor
   or load-mutate-save, ADR-0006) is in scope.
8. **The gate:** `save/save_validator.gd` (`class_name SaveValidator`),
   static `validate_character(data: Dictionary) -> Dictionary` returning a
   sanitized deep copy. Every load path goes through it before any
   `load_state` runs — no exceptions, this is the ADR-0015 single gate.
   Rules for v1: missing/mistyped sections replaced by defaults; `level`
   int ≥ 1; `xp` int clamped to `[0, xp_to_next(level) - 1]`; pool
   currents numeric; `known` filtered to ids the catalog resolves;
   `equipped` forced to `SLOT_COUNT` entries, each id filtered to
   membership in the sanitized `known` (else `null`). Each repair emits
   `push_warning` naming the field.
9. **Loading replaces the authored default kit.** `Player._ready()`'s
   hardcoded learns/equips stay — they are the new-character kit. When
   `load_character` applies a document, `Player.load_skill_state` rebuilds:
   clear `known_skills`, learn each known id via the catalog, unequip all
   slots, equip each non-null `equipped[i]` into slot `i`.
10. **Triggers.** Save: `SaveManager._notification(what ==
    NOTIFICATION_WM_CLOSE_REQUEST)` → `save_character(player)`. Load:
    `main.gd _ready()` calls `SaveManager.load_character(player)` after the
    existing HUD/camera wiring (equips fire `slot_changed`, so the bound
    skill bar updates itself). SaveManager finds the player via
    `get_tree().get_first_node_in_group(&"player")`; add the Player to
    group `player` (in `Player.tscn` node groups). Editor-stop doesn't
    deliver WM_CLOSE_REQUEST — known, accepted (ADR-0015).
11. **Corrupt/future files:** unparseable JSON or `version` > 1 → rename
    the file to `<name>.json.corrupt` (overwriting a previous `.corrupt`),
    `push_warning`, return `false` (fresh character). Never silently
    delete user data.

## Invariants to respect

- No runtime state on Resources (ADR-0003): the catalog is authored data;
  never write character state into a `Skill` or the catalog resource. The
  trap: "just save the modified .tres" is exactly the forbidden shape.
- Never serialize `StatModifier`s (ADR-0015 decision 4). The trap: a
  "generic" component serializer that walks `_mods` looks helpful and
  double-applies growth on every load.
- Components stay symmetric (ADR-0002): `save_state`/`load_state` take no
  player-specific assumptions; only `SaveManager`'s player lookup and
  `Player`'s skill state are player-scoped.
- Authored `.tres` edits are load-mutate-save or in-editor (ADR-0006).
- Failure/warning strings follow existing style; new failure reasons (none
  expected) would be `StringName`s.

## Documentation this brief owes

- **CONTEXT.md**: entries for **Character File** (one character's
  persisted state; validated at the Save Gate on every load), **Account
  File** (account-wide state — roster now, Bonds later; survives character
  deletion), **Save Gate** (the single validator every character document
  passes through before any state applies — M2 gear, M3 spliced skills,
  M5 oaths extend it), and **Skill Catalog** (the authored id→Skill
  registry; the only legal way to resolve a persisted skill id).
- ADR-0015 already exists — cite it, don't write a new one.

## Acceptance criteria

- Play a session (gain XP, level up, spend mana, take damage, re-equip a
  skill into a different slot), save, rebuild the scene fresh, load: level,
  XP, current health, current mana, known skills, and per-slot equips match
  exactly. Max pools reflect level growth exactly once.
- Loading a level-N character yields the same `get_stat(MAX_HEALTH)` as
  leveling to N in play (replay equivalence), and a save→load→save cycle
  produces an identical character document (round-trip stability, the
  double-apply guard).
- With no save files present, the game starts with the authored default
  kit and `load_character` returns `false` without warnings.
- `delete_character(&"default")` removes the character file and roster
  entry; `account.json` still exists and parses.
- A character document with an unknown skill id, an equipped id missing
  from known, out-of-range xp, and `current <= 0` health loads without
  errors: the unknown id is gone, the bad slot is empty, xp is clamped,
  health is full — one warning per repair.
- A truncated/garbage character file is renamed `.corrupt`, the game
  starts fresh, and the next save writes a valid file.
- Every asset in `skills/library/` appears in `skill_catalog.tres` and all
  ids are unique and non-empty (test-enforced).
- Full GUT suite green (new `class_name`s ⇒ run `--headless --import`
  first and confirm the new test files appear in GUT's output).

## Test ideas

- Pure round-trip: build the standard test entity graph (StatsComponent
  named `"StatsComponent"` etc.), mutate (award XP past two levels, damage,
  spend mana), `serialize_character` → fresh graph → `apply_character` →
  assert accessors match and `get_stat(MAX_HEALTH)` equals the played
  graph's.
- Replay equivalence: `apply_character` with `{"experience": {"level": 5,
  "xp": 0}}` vs `award_xp` to level 5 → identical max health; serialize
  both → identical documents.
- Validator table-drive: each malformed input from the acceptance list →
  sanitized output field-by-field; `watch_signals` isn't needed —
  `push_warning` behavior can be asserted via GUT's expected-error
  helpers or simply by the sanitized result.
- Pools: load `{"health": {"current": -5}}` → full; `{"current": 40}`
  with max 100 → 40; `{"current": 4000}` → clamped to max.
- Disk layer: point `save_root` at a scratch dir, save → both files exist
  and parse; delete_character → character file gone, account intact;
  corrupt file → `.corrupt` rename. Clean up in `after_each`.
- Catalog completeness: `DirAccess` over `res://skills/library/`, every
  `.tres` present in the catalog, ids unique.

## Out of scope

- Any UI: character select, save/load menus, "saving…" toast, name entry.
- Multiple characters (the schema supports it; nothing else does yet).
- Autosave timers, save-on-level-up, checkpoints — save happens on quit.
- Persisting position, buffs, cooldowns, enemy or level state (ADR-0015
  drops them deliberately).
- Settings/options persistence (audio, keybinds) — not character data.
- Account file content beyond the roster (Bonds are M6).
- Respawn flow changes — death handling stays exactly as it is.
