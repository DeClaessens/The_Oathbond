# Save architecture: split files, JSON documents, component-owned state, one validation gate

Persistence (M1, VISION structural decision 1) is built on four decisions made together, because each one constrains the others.

**1. Account and character state are separate files from the first commit.** `user://saves/account.json` holds account-wide state (today: a version and a character roster; later: Bonds, oath collections, unlocks). `user://saves/characters/<id>.json` holds one character's everything (level, XP, pools, known/equipped skills; later: gear instances, spliced skills, oath state). Deleting a character deletes its file and its roster entry — never the account file. M1 has exactly one character, id `default`; multi-character support is a directory listing away, not a schema change.

**2. Documents are JSON with an integer `version`, migrated sequentially at load.** `JSON.stringify(data, "\t")` / `JSON.parse_string`. JSON over Godot's own formats for two reasons: a saved `.tres`/`ConfigFile` in a user-writable location can smuggle executable content (`Resource` loading instantiates scripts — a real attack surface once saves are shared), and JSON is diffable and debuggable by eye. Every document carries `version: int` (starts at 1); the loader upgrades old documents one version step at a time in a single migration function before validation. A document that cannot be parsed, or whose version is newer than the build understands, is renamed in place to `<name>.json.corrupt` (preserving the data for post-mortem) and the game starts that scope fresh.

**3. Components own their serialization; SaveManager composes.** Runtime state lives on component Nodes (ADR-0003), so each stateful component exposes `save_state() -> Dictionary` and `load_state(data: Dictionary) -> void`, and the `SaveManager` autoload only assembles/distributes the per-component sections plus the document envelope. This keeps the symmetric-component principle (ADR-0002): a future enemy or NPC that needs persisting reuses the same component methods, and a new stateful component adds its own section without touching a central serializer's switch statement.

**4. Persist the authoritative minimum; everything derived is replayed, everything transient is dropped.** The save schema stores only state that cannot be recomputed:

- *Persisted*: level, XP-within-level, current health, current mana, known skill ids, equipped skill ids per slot.
- *Replayed at load*: level-up growth. Growth lives at runtime as unkeyed permanent `StatModifier`s in `StatsComponent._mods`; serializing those would double-apply on every load cycle. Instead the character file stores only `level`, and `ExperienceComponent.load_state` re-applies the growth modifiers for levels 2..N (without the level-up full restore).
- *Dropped*: max pools (always derived via `get_stat`), timed buff modifiers, slot cooldowns and the GCD (transient combat state — a resumed character starts combat-clean), `StatModifier.source` (a live object reference, unserializable by nature).

**The one gate.** Every character document — regardless of where it came from — passes through a single validator before any `load_state` is called. The validator sanitizes rather than rejects: unknown skill ids are dropped, equipped ids not present in known skills become empty slots, numbers are clamped to legal ranges, and each repair emits a warning. This is the load-bearing pattern three future systems already converge on (VISION, `docs/design/stats-and-gear.md`): rolled gear instances, spliced skills, and oath constraints are all *player-authored save data validated at one gate* — M2/M3/M5 extend this validator, they do not add their own.

**Skill identity.** Skills serialize as `Skill.id` (`StringName`), never as resource paths (paths break on refactors and some assets lack stable uids). Loading by id requires the project's first id→asset registry: an authored `SkillCatalog` resource listing every skill asset, from which a lookup dictionary is built at startup. Duplicate or empty ids in the catalog are authoring errors surfaced with `push_error`.

## Considered Options

- **`ResourceSaver`/`.tres` saves** — rejected: executable-content risk in user-writable files, and ADR-0003 already pushed runtime state off Resources, so there is no natural Resource to save.
- **One combined save file** — rejected outright by VISION structural decision 1: the account/character split must exist from the first save commit so seasons/Bonds never require a save-format fork.
- **A central serializer that reads component internals** — rejected: every new stateful component would grow the central switch, and it breaks encapsulation the `of()`-helper architecture establishes. Component-owned `save_state`/`load_state` scales with the component roster.
- **Persisting growth modifiers directly** — rejected: `_mods` entries are indistinguishable from transient buffs except by convention, `source` refs don't serialize, and replaying from `level` is exact by construction.

## Consequences

- Load order matters and is fixed: experience (growth modifiers raise max pools via `stat_changed`) → health → mana → skills. Pools' `load_state` must run *after* growth replay or the level-up restore semantics clobber the persisted current values.
- `ExperienceComponent` needs its growth-modifier application split from its full-restore behavior so load can replay one without the other.
- The validator needs the catalog, so the `SkillCatalog` is a hard dependency of the save system, and adding a new authored skill now includes adding it to the catalog (a test should enforce catalog completeness against `skills/library/`).
- Saving on quit uses `NOTIFICATION_WM_CLOSE_REQUEST`; stopping the game from the Godot editor does not deliver it, so editor-stopped sessions don't save. Acceptable for M1; a manual save trigger can be added when a menu exists.
- A dead character is never resumed dead: persisted current health ≤ 0 loads as a full restore. Death is a moment, not a state to reload into (consistent with the cheap-respawn direction of the M0.7 open question).
- Future save-data systems (gear rolls M2, spliced skills M3, oath state M5) each add a section to the character document, a component `save_state`/`load_state` pair, and validator rules — nothing else.
