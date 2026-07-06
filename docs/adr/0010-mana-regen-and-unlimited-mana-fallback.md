# Mana regenerates unconditionally; a caster with no ManaComponent has unlimited Mana

Mana is a second Resource Pool, following the same split ADR-0009 established for Health: current Mana lives on a new `ManaComponent`, while `Max Mana` and `Mana Regen` are ordinary Stats on `StatsComponent` (buffable through the existing modifier pipeline, same as `Max Health`). Two decisions here go beyond copying that pattern and are worth recording.

**Regen is continuous and unconditional.** `ManaComponent._process(delta)` adds `Mana Regen * delta` every frame with no cast-interrupts-regen delay, even though that's a common ARPG convention. We deliberately kept the simplest version — nothing in the current design needs the delay, and adding a suppression timer later is a small, additive change to `ManaComponent`, not a redesign.

**A caster with no `ManaComponent` is treated as having unlimited Mana**, not as a misconfiguration. This is a deliberate asymmetry with `HealthComponent`, which `push_error`s and disables itself when its required `StatsComponent` sibling is missing. `AbilityComponent` is shared by every caster (ADR-0002), but only Player has a `ManaComponent` today; a future enemy that casts for free can keep using mana-cost Skills without needing a dummy `ManaComponent` wired in just to satisfy a check.

## Consequences

- `AbilityComponent.activate()` calls `ManaComponent.of(caster)`; a `null` result skips the affordability check entirely rather than failing the cast.
- Any future caster that *should* be constrained by Mana must have a `ManaComponent` — its absence is silently permissive, not loud, so a missing component reads as "unlimited," not as a bug.
