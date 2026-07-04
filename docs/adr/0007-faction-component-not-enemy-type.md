# Characters are composed, not subclassed by faction

There is no `Enemy` (or `Player`) base class or scene. Any character — casting or not — is a plain physics body assembled from components: `StatsComponent` for numbers, `FactionComponent` for which side it's on, and (only if it can act) `AbilityComponent`. Training Dummy is the proof: it's a `CharacterBody2D` + `StatsComponent` + `FactionComponent`, nothing else.

`FactionComponent` carries identity only — a closed `Faction` enum (`PLAYER`, `ENEMY`, `NEUTRAL`) resolved by fixed child name via `FactionComponent.of()`, mirroring `StatsComponent.of()`. It does not resolve hostility between factions; that's the future target-selection system's job (the same system that will make `Targeting.ENEMY`/`ALLY` resolvable). Keeping the two separate means a future neutral creature or player pet is a new faction value, not an architecture change.

Because faction is a composable identity rather than a skill concern, `StatsComponent` and the new `FactionComponent` moved out of `skills/` into a new `components/` directory — both are attached to any character regardless of whether it participates in the skill system at all.

## Considered Options

A dedicated `Enemy` base scene that concrete enemy types (Training Dummy, etc.) would inherit via Godot scene inheritance was the obvious alternative, mirroring how `Player` looks today. Rejected: it introduces a second extension mechanism (node-tree inheritance) alongside the composition the skill system already uses everywhere else, and any enemy that doesn't act would either drag in an unused `AbilityComponent` from the base or need a per-scene override to remove it.

A Godot group (`add_to_group("enemies")`) instead of `FactionComponent` was considered for identity. Rejected: group membership is binary (in the group or not), but future factions need relative hostility (a pet is friendly to the player, hostile to enemies; a neutral creature is hostile to no one) — a relationship groups don't model.
