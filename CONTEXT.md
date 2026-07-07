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

**Floating Combat Text**:
A short-lived number that appears at a character's position when a hit lands, drifts upward, and fades — each hit spawns its own independent instance. Triggered globally off `Events.damage_dealt`, not owned by or bound to any single entity.
_Avoid_: Hitsplat, damage number, damage popup
