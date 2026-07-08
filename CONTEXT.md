# Oathbond

A 2D action game (Godot 4.7) built around a composable skill and stat system shared by the player and enemies alike.

## Language

### Skills

**Skill**:
The equippable, data-authored thing a character casts — metadata (name, cooldown, targeting) plus an ordered list of Skill Effects.
_Avoid_: Ability, spell, move

**Skill Effect**:
One unit of behavior a Skill performs on activation, such as dealing damage, applying a modifier, or spawning a projectile. A Skill is a composition of one or more of these.
_Avoid_: Action, behavior

**Ability Slot**:
One of a character's four equip slots. Holds one Skill and tracks that slot's own cooldown, independent of the Skill itself and of any other character's slot holding the same Skill.
_Avoid_: Slot (on its own), loadout slot
_Known drift_: the Skill Bar's per-slot UI class is named `SkillSlot` (`ui/skill_bar/skill_slot.gd`), not `AbilitySlotView` or similar — tracked as tech debt, not yet renamed.

**Caster**:
The character — player or enemy — that activates a Skill.
_Avoid_: User

**Targeting**:
The declarative hint on a Skill (Self / Ally / Enemy / Area / None) describing who it's meant to affect. The caller resolves the actual targets; Targeting only describes intent.
- **Self**: resolves to the caster as the sole target.
- **Area**: resolves to an aim direction from wherever the caster is pointing (mouse position, stick input); carries no discrete targets.
- **None**: resolves to no targets and no aim direction — for effects that read neither.
- **Enemy**: resolves to the living hostile character (see Hostility) nearest the aim point within `TargetSelection.SNAP_RADIUS` and the Skill's `targeting_range`; if none is near the aim point, falls back to the living hostile nearest the caster within range; `null` (cast fails with `&"no_target"`) only when no living hostile is in range at all.
- **Ally**: same snap-then-fallback rule over allied characters, but the caster itself always counts as a candidate — so Ally targeting degenerates to the caster when no other ally is around, rather than failing.
_Avoid_: Target type

**Known Skill** / **Equipped Skill**:
A Known Skill is one a character has learned and can equip. An Equipped Skill is a Known Skill currently placed in one of the character's Ability Slots. Learning and equipping are deliberately separate actions — a character can know a skill without it being equipped.
_Avoid_: Learned skill (use Known Skill)

**Global Cooldown** (GCD):
A short, shared lockout on `AbilityComponent` that starts on any successful cast and briefly blocks every Ability Slot, not just the one used. Sets combat cadence independent of each Skill's own cooldown. A Skill can opt out via `ignores_global_cooldown`, meaning it neither respects the GCD (castable during it) nor triggers it (casting it starts nothing) — used for movement Skills like Sprint and Super Jump, which must never feel input-gated.
_Avoid_: Cast time, shared cooldown (use Global Cooldown / GCD)

**Skill Bar**:
The player's on-screen HUD that reflects their four Ability Slots — which Skills are equipped, which slots are open, and each slot's live cooldown. Read-only: it mirrors the `AbilityComponent`'s state, it does not equip or activate.
_Avoid_: Hotbar, action bar, ability bar

### Stats & modifiers

**Stat**:
A named numeric attribute of a character (e.g. move speed, max health) produced by composing a base value with any active Modifiers. Recomputed fresh from base + active Modifiers every time it's read — it has no memory of its own. Contrast with a Resource Pool.
_Avoid_: Attribute, property

**Attribute**:
One of the three player-grown Stats — Might, Grace, Wit — allocated from Attribute Points rather than authored on `base_stats`. Ordinary Stats otherwise: string-keyed (`StatKeys.MIGHT`/`GRACE`/`WIT`, not `Stat` enum entries), composed the same way, and a future gear system can add to them directly (M2.4). Their entire purpose is feeding Derived Stats — see ADR-0016.
_Avoid_: Ability score, primary stat

**Derived Stat**:
A Stat whose value partly comes from an Attribute through the fixed one-way table in `StatsComponent.DERIVATIONS`, resolved inside `get_stat` at the FLAT tier: Max Health from Might (×2.0), Max Mana from Wit (×1.0), and `crit_multi` from Grace (×0.005). The table is one-way by construction — a Derived Stat is never itself a source — so cycles can't be introduced. See ADR-0016.
_Avoid_: Secondary stat

**Modifier**:
A Flat, Additive%, or Multiplicative% adjustment to one Stat, either permanent or timed, applied via a Skill Effect.
_Avoid_: Bonus

**Buff**:
A Modifier that improves a Stat.

**Debuff**:
A Modifier that weakens a Stat. This is a domain distinction the implementation doesn't yet enforce mechanically — today Buff and Debuff both go through the same class (`StatBuffEffect`/`StatModifier`), distinguished only by the sign of the value.
_Avoid_: Negative buff

**Damage Type**:
The classification of a hit that selects which offensive Modifiers scale it outgoing and which Resistance reduces it incoming. The roster is Physical, Ember, Radiance, and Rot (see `docs/design/stats-and-gear.md` for what each means in the world).
_Avoid_: Element, school, Fire (renamed to Ember 2026-07-06)

**Resistance**:
A Stat that reduces incoming damage of one Damage Type, capped so a character is never fully immune.
_Avoid_: Defense, armor

**Crit**:
A per-hit, caster-side random event: `crit_chance` gates whether it occurs, `crit_multi` scales the payoff. Rolled once when the Damage Packet is built — at cast for instant effects, at spawn for projectiles — never re-rolled and never rolled on the victim's side; Resistance still applies after, in the normal order. See ADR-0017.
_Avoid_: Critical hit chance/damage as separate ad-hoc fields — they're Stats like any other, composed the same way.

**Damage Packet**:
The outgoing-damage seam's return value — `{amount, type, is_crit}` (`DamagePacket`) — that replaced the bare scaled float `scale_outgoing` used to return. `scale_outgoing` still does the deterministic per-type `dmg_<type>` scaling (ADR-0004); `StatsComponent.roll_outgoing` wraps it and layers the Crit roll outside, so both damage call sites (`DamageEffect`, `SpawnProjectileEffect`) share one path and the crit flag survives to the Floating Combat Text. See ADR-0017.
_Avoid_: Reusing a bare float or a Dictionary for the outgoing result.

**Cooldown Reduction**:
A Stat that scales a skill's own per-slot cooldown down at the moment it starts, capped at `AbilityComponent.CDR_CAP` (0.75). Deliberately never touches the Global Cooldown, which is the game's tempo floor, not a stat-scaled value.
_Avoid_: Speeding up or shortening the GCD.

**Mana-Cost Reduction**:
A Stat that scales a skill's mana cost down at the moment of spend, capped at `AbilityComponent.MCR_CAP` (0.75). The same reduced cost is used for the affordability check and the actual spend so the two can never disagree.

### Identity

**Faction**:
The side a character belongs to — Player, Enemy, or Neutral — carried by a `FactionComponent`. Identity only: it says what a character is, not who it's hostile to. Resolving hostility between Factions (e.g. for Ally/Enemy Targeting) is `TargetSelection`'s job (see Hostility).
_Avoid_: Team, side (on their own)

**Hostility**:
The relationship between two Factions — hostile, allied, or neither — resolved by `TargetSelection.is_hostile`/`is_allied` (`skills/targeting/target_selection.gd`), never stored on `FactionComponent`. Player and Enemy are mutually hostile; Neutral is hostile to nothing and nothing is hostile to it; a shared Faction is allied (including a character with itself, so Ally targeting always has a fallback). See ADR-0013 for why this is a static rule rather than a data-driven matrix.
_Avoid_: Team check, alignment

### Composition

**Component**:
A node attached to a character that gives it one capability — numeric attributes (`StatsComponent`), side/identity (`FactionComponent`), or a Health readout (`HealthComponent`). Most Components own the data for their capability outright; `HealthComponent` is the exception — it owns no data itself and instead orchestrates a Resource Pool that lives elsewhere plus the view that renders it. Characters are assembled from Components rather than subclassed by type — see ADR-0007.
_Avoid_: System (too broad), Manager

**AI Controller**:
The Component (`AiControllerComponent`) that drives a non-player character through a three-state loop — Idle, Chase, Attack — using the same detection (`TargetSelection.find_enemy`) and the same `AbilityComponent.activate()` call a player's input would make. It never resolves targeting or damage itself; it only decides when to walk and when to press the button. Aggro Range is the distance within which it notices a hostile at all, independent of the equipped Skill's own `targeting_range`, which gates Attack.
_Avoid_: Enemy AI (too broad — this Component is the behavior loop specifically, not "everything about how an enemy behaves")

### Health & combat feedback

**Resource Pool**:
A stateful, depletable/restorable quantity bounded by a maximum, unlike a Stat it persists across frames instead of being recomputed fresh from Modifiers each time it's read. Health and Mana are the game's Resource Pools — see ADR-0009 for why a Resource Pool isn't a Stat despite living alongside them for a while.
_Avoid_: Stat (for anything with memory or depletion)

**Health**:
A character's current hit points — a Resource Pool owned by `HealthComponent`, bounded by the `Max Health` Stat (itself still composed from base + Modifiers, so a future Vitality-style buff can raise the ceiling). Clamped to 0 on defeat, which triggers Death.
_Avoid_: HP as a Stat, Hit Points

**Death**:
The latched transition of a character's Health to 0. `HealthComponent` detects and announces it (a local `died` signal plus the cross-cutting `Events.character_died` carrying victim and killer); what happens next is the character's own composed-in response — enemies despawn via `DespawnOnDeathComponent`. The player has no death response yet. Once dead, further damage is ignored until `restore_full()` clears the latch — see ADR-0012.
_Avoid_: Kill/destroy (as system verbs), defeat (for the mechanical state)

**Health Bar**:
The on-screen readout of a character's Health — a bar that starts full green, with red revealed from the right as Health drops. Purely presentational: it renders whatever `HealthComponent` reports and owns no state of its own.
_Avoid_: HP bar

**Mana**:
A character's casting resource, spent to activate Skills that carry a mana cost — a Resource Pool owned by `ManaComponent`, bounded by the `Max Mana` Stat and replenished continuously at the `Mana Regen` Stat's rate. A caster with no `ManaComponent` has unlimited Mana rather than failing every cast — see ADR-0010.
_Avoid_: MP, magic points, energy

**Mana Bar**:
The on-screen readout of a character's Mana — a bar stacked directly beneath the Health Bar, always visible since Mana depletes routinely during normal play (unlike the Health Bar, which stays hidden until the first hit). Purely presentational, same role as Health Bar.
_Avoid_: MP bar

**Health Regen**:
A Stat, base 0, that continuously refills Health up to Max Health at its rate per second — mirrors Mana Regen's `_process` loop on the sibling Resource Pool, never regenerates a dead character, and only emits `health_changed` when the value actually moves.
_Avoid_: Free regen by default — it is purely an affix payoff.

**Floating Combat Text**:
A short-lived number that appears at a character's position when a hit lands, drifts upward, and fades — each hit spawns its own independent instance. Triggered globally off `Events.damage_dealt`, not owned by or bound to any single entity.
_Avoid_: Hitsplat, damage number, damage popup

### Progression

**Experience** (XP):
A quantity a character earns by killing others, tracked by `ExperienceComponent` as progress within the current Character Level toward the next. Earned, never spent — it fills the level bar and is gone once it converts. Awarded by `ExperienceComponent` itself off `Events.character_died` when the killer is its own parent; a `null` killer (environmental death) or a victim with no `XpRewardComponent` grants nothing, and a character cannot earn Experience by killing itself.
_Avoid_: XP as a Stat (it isn't modified by buffs — it's a running count, not a composed value)

**Character Level**:
A character's permanent progression tier, starting at 1 and rising when accumulated Experience crosses `xp_to_next(level)`. Each level-up grants permanent flat growth (`+Max Health`, `+Max Mana`) applied as stacking Modifiers — never by mutating `base_stats` — plus a full restore of Health and Mana. Distinct from the world **Level** above — same word, unrelated concept; say "character level" or "the level scene" when ambiguous. Persisted as `level`/`xp` only (M1); the growth Modifiers themselves are never serialized, they're replayed from `level` on load (see Save Gate).
_Avoid_: Player Level (levels apply to any character, not just the player), XP Level

**Attribute Point**:
The per-level allocation currency spent into an Attribute, owned by `AttributesComponent`. `STARTING_POINTS` are available at Character Level 1 (an immediate build decision); each level-up grants `POINTS_PER_LEVEL` more. Unspent until spent; a Respec (free and unlimited at M2 — no economy exists yet) returns every allocated point to unspent and drops the Attribute back to 0.
_Avoid_: Skill point (that name is reserved for a future Skill Splicing currency, M3+), talent point

### Persistence

**Character File**:
The single JSON document at `user://saves/characters/<id>.json` holding one character's everything — level, XP, current Health and Mana, known/equipped Skill ids. Written by `SaveManager` on quit, composed from each stateful Component's own `save_state()`; loaded and passed through the Save Gate before any `load_state()` runs. M1 has exactly one character, id `default`. What it deliberately excludes — max pools, timed Modifiers, cooldowns, position — is dropped because it's either derived or transient (ADR-0015).
_Avoid_: Save file (ambiguous with Account File), profile

**Account File**:
The JSON document at `user://saves/account.json` holding account-wide state — today just the character roster, later Bonds and oath collections (M6+). Survives character deletion; `SaveManager.delete_character` removes a Character File and its roster entry but never touches this file.
_Avoid_: Profile, save slot

**Save Gate**:
`SaveValidator.validate_character`, the single point every Character File passes through before any Component's `load_state()` runs, regardless of where the document came from (disk, a future import, a future migration). Sanitizes rather than rejects: unknown Skill ids are dropped, an equipped id missing from known becomes an empty slot, numbers are clamped to legal ranges, and each repair emits a `push_warning`. M2 gear rolls, M3 spliced Skills, and M5 oath state each extend this one gate rather than inventing their own (ADR-0015).
_Avoid_: Sanitizer, schema check (this is specifically the load-bearing single gate, not general input validation)

**Skill Catalog**:
`SkillCatalog`, the authored `res://skills/skill_catalog.tres` resource listing every Skill asset under `skills/library/` (enemy Skills included), and the only legal way to resolve a persisted Skill id back into a `Skill` (`SkillCatalog.by_id`). Exists because Skills serialize as `Skill.id`, never as resource paths — paths break on refactors. Duplicate or empty ids in the catalog are authoring errors, surfaced with `push_error`.
_Avoid_: Skill registry, skill database

### Items & gear

**Item Definition**:
The authored base item type — a "Rusted Sickle" — carried by an `ItemDefinition` Resource (`items/core/item_definition.gd`): its stable `id`, display name, icon, equip `slot`, `material` tag, fixed `implicit_mods`, the `affix_pool` it rolls from, and the `attribute_requirement` M2.4's equip gate reads. The definition half of the definition/instance split (ADR-0003, third appearance after the skill/save split): shared, immutable, never mutated by a roll. Listed in the Item Catalog and resolved by id, exactly like a Skill.
_Avoid_: Item type as a class per item, base item as save data

**Item Instance**:
A rolled drop — an `ItemInstance` (`items/core/item_instance.gd`) holding a `definition_id`, a `Rarity`, and its `rolled_affixes`. Runtime/save data only: `RefCounted`, **never** a Resource and never a `.tres` (ADR-0003), persisted as a plain dict through the single Save Gate (ADR-0015). Resolves its definition through the Item Catalog; the instance is where an item's own rolled numbers live, distinct from the definition's authored ranges.
_Avoid_: Dropped item as a mutated Resource, storing a roll as a `.tres`

**Affix**:
One rolled stat modifier on an Item Instance — an `ItemAffix` (`items/core/item_affix.gd`, `RefCounted`): a `stat`, a `StatModifier.Op`, and a rolled `value`. On equip (M2.4) each becomes a `StatModifier` sourced to the instance. Authored ranges live in an `AffixEntry` (a Resource) inside an `AffixPool`; an implicit mod is authored as an `AffixEntry` with `min_value == max_value`. `ItemAffix.triple()` reads a `{stat, op, value}` triple from either source so implicit and rolled mods iterate uniformly.
_Avoid_: Prefix/suffix (no such split at M2), a separate `dmg_flat_<type>` key (flat added damage is just a FLAT-op affix on `dmg_<type>`)

**Rarity**:
An Item Instance's tier — `COMMON` (0 affixes), `QUALITY` (1–2), `MASTERWORK` (3–5), `HEIRLOOM` (authored). The `ItemRoller` picks rarity by weight (Common 60 / Quality 30 / Masterwork 10) and never rolls a Heirloom — Heirlooms are hand-made, the enum value exists but the roller never produces one. Append-only, order frozen; a saved instance stores the int.
_Avoid_: Quality as a numeric score, rolling Heirlooms

**Item Catalog**:
`ItemCatalog`, the authored `res://items/item_catalog.tres` resource listing every `ItemDefinition` under `items/library/`, and the only legal way to resolve a persisted `definition_id` back into a definition (`ItemCatalog.by_id`). The exact twin of the Skill Catalog — lazy static lookup, `push_error` on duplicate or empty ids, one completeness test against the definitions folder. Exists for the same reason: instances serialize by id, never by resource path.
_Avoid_: Item registry, item database

### World

**Level**:
The engine container a piece of the world is built from — geometry (floor, walls, platforms) plus a `bounds: Rect2` the camera clamps to (`levels/level.gd`, `class_name Level`). Placeholder today (`levels/proving_grounds/`); come M4, a Zone is a Level with identity — art, ambience, mastery — layered on top. Entity-free by design: a level scene owns geometry only, not who spawns in it. Distinct from **Character Level** (M0.4's XP-driven character progression rank) — same word, unrelated concept; when ambiguous, say "the level scene" or "character level" explicitly.
_Avoid_: Map, stage

**Follow Camera**:
The `Camera2D` that tracks the player, owned by `Player.tscn` (not the level) per ADR-0014 — the player is the only thing a solo game's camera ever follows. Smoothed (`position_smoothing_enabled`, `position_smoothing_speed`) and clamped to the current `Level`'s `bounds` (`limit_smoothed` plus `limit_left/top/right/bottom`, copied on by `main.gd`), so the view never shows past the level's edges.
_Avoid_: Viewport, follow cam
