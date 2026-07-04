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
- **Ally** / **Enemy**: not yet resolvable — there is no target-selection system. A Skill authored with either fails loudly (the caster has no way to find "an ally" or "an enemy" yet) rather than falling back to a guess.
_Avoid_: Target type

**Known Skill** / **Equipped Skill**:
A Known Skill is one a character has learned and can equip. An Equipped Skill is a Known Skill currently placed in one of the character's Ability Slots. Learning and equipping are deliberately separate actions — a character can know a skill without it being equipped.
_Avoid_: Learned skill (use Known Skill)

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
The classification of a hit (e.g. Physical, Fire) that selects which offensive Modifiers scale it outgoing and which Resistance reduces it incoming.
_Avoid_: Element, school

**Resistance**:
A Stat that reduces incoming damage of one Damage Type, capped so a character is never fully immune.
_Avoid_: Defense, armor

### Identity

**Faction**:
The side a character belongs to — Player, Enemy, or Neutral — carried by a `FactionComponent`. Identity only: it says what a character is, not who it's hostile to. Resolving hostility between Factions (e.g. for Ally/Enemy Targeting) is a future target-selection system's job.
_Avoid_: Team, side (on their own)

### Composition

**Component**:
A node attached to a character that gives it one capability — numeric attributes (`StatsComponent`), side/identity (`FactionComponent`), or a Health readout (`HealthComponent`). Most Components own the data for their capability outright; `HealthComponent` is the exception — it owns no data itself and instead orchestrates a Resource Pool that lives elsewhere plus the view that renders it. Characters are assembled from Components rather than subclassed by type — see ADR-0007.
_Avoid_: System (too broad), Manager

### Health & combat feedback

**Resource Pool**:
A stateful, depletable/restorable quantity bounded by a maximum, unlike a Stat it persists across frames instead of being recomputed fresh from Modifiers each time it's read. Health is the first Resource Pool in the game — see ADR-0009 for why it isn't a Stat despite living alongside them for a while.
_Avoid_: Stat (for anything with memory or depletion)

**Health**:
A character's current hit points — a Resource Pool owned by `HealthComponent`, bounded by the `Max Health` Stat (itself still composed from base + Modifiers, so a future Vitality-style buff can raise the ceiling). Clamped to 0 on defeat; no death handling exists yet.
_Avoid_: HP as a Stat, Hit Points

**Health Bar**:
The on-screen readout of a character's Health — a bar that starts full green, with red revealed from the right as Health drops. Purely presentational: it renders whatever `HealthComponent` reports and owns no state of its own.
_Avoid_: HP bar

**Floating Combat Text**:
A short-lived number that appears at a character's position when a hit lands, drifts upward, and fades — each hit spawns its own independent instance. Triggered globally off `Events.damage_dealt`, not owned by or bound to any single entity.
_Avoid_: Hitsplat, damage number, damage popup
