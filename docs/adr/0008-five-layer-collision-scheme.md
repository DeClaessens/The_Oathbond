# Physics layers, not Faction, gate what a projectile can hit

Collision is split into five physics layers: `World` (1), `Player` (2), `Enemy` (4), `PlayerProjectile` (8), `EnemyProjectile` (16). A projectile's `collision_layer` identifies which side fired it; its `collision_mask` lists what it's allowed to hit. `PlayerProjectile` masks in `World | Enemy` (5) — it hits terrain and enemies, never the player who fired it. An eventual `EnemyProjectile` mirrors this with `collision_mask = World | Player` (3).

Characters mask more conservatively: `Player` currently masks `World` only (1) — it doesn't physically collide with `Enemy` bodies at all, so contact damage isn't a physics-layer concern today.

## Considered Options

Gating hits through `FactionComponent` (query the target's faction at collision time, `body_entered` → check hostility) was the alternative. Rejected for now: `FactionComponent` is explicitly identity-only (ADR-0007) with no hostility resolution, and physics layers already let the engine's broadphase skip impossible collision pairs for free instead of doing a component lookup per contact. If a future faction (a neutral creature, a player pet) needs hit rules layers can't express — e.g. one Enemy's projectile should ignore another Enemy — this scheme will need to grow a `FactionComponent` check on top, not replace it.

## Consequences

Adding a new spawnable side (e.g. a hazard, a pet) means adding a new layer, not reusing an existing one — layers are cheap (32 available) and mixing two unrelated actors onto one layer silently over- or under-couples their collisions.
