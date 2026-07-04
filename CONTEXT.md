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

**Caster**:
The character — player or enemy — that activates a Skill.
_Avoid_: User

**Targeting**:
The declarative hint on a Skill (Self / Ally / Enemy / Area / None) describing who it's meant to affect. The caller resolves the actual targets; Targeting only describes intent.
_Avoid_: Target type

**Known Skill** / **Equipped Skill**:
A Known Skill is one a character has learned and can equip. An Equipped Skill is a Known Skill currently placed in one of the character's Ability Slots. Learning and equipping are deliberately separate actions — a character can know a skill without it being equipped.
_Avoid_: Learned skill (use Known Skill)

### Stats & modifiers

**Stat**:
A named numeric attribute of a character (e.g. move speed, health) produced by composing a base value with any active Modifiers.
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
