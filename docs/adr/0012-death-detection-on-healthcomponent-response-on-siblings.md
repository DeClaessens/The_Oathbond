# Death detection lives on HealthComponent; the death response is the character's own

`HealthComponent` owns the Health Resource Pool (ADR-0009), so it is the one node that knows the moment Health transitions to 0. It detects Death and announces it two ways: a local `died` signal for the character's own nodes, and the cross-cutting `Events.character_died(victim, killer)` for systems that care about *any* death (the planned XP, loot, and quest systems — more than one consumer, so it earns a place on the `Events` autoload).

What `HealthComponent` deliberately does **not** do is decide what death *means*. That response differs per character and is composed in, ADR-0007 style, rather than special-cased inside the health code:

- Enemies carry a `DespawnOnDeathComponent` that `queue_free`s the character on `died`.
- The player's script connects `died` to a respawn: back to the spawn point with Health and Mana restored via the pools' `restore_full()`.

Death is **latched**: once dead, `HealthComponent` ignores further `apply_damage` calls and will not re-emit `died` until something calls `restore_full()`, which clears the latch. This keeps "die once per death" an invariant of the detector instead of a defensive check every responder must repeat (e.g. a projectile hitting a corpse on its despawn frame must not kill it twice).

## Consequences

- A character with Health but no death response is valid — it just sits at 0 HP ignoring damage (today's behavior for anything not yet wired). Death responses are opt-in per scene, like every other capability.
- Anything that revives or heals a dead character must go through `restore_full()` (or a future `heal()` that explicitly manages the latch); writing `_current` alone would leave the character unkillable.
- There is no death penalty yet. That is an open design question in `docs/VISION.md`, deliberately deferred until Oaths exist (oaths may interact with death rules).
- `Events.character_died` carries the fatal hit's `source` as `killer`, which may be `null` (environmental damage, tests). The XP system must decide what a null killer means before awarding anything. **Decided (M0.4):** a `null` killer grants no XP to anyone — environmental deaths feed no one, and that's fine until some system needs otherwise.
