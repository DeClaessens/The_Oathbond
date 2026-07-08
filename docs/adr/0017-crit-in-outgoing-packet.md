# Crit rolls in the outgoing damage packet; the crit flag rides damage_dealt to the FCT

Crit is a per-hit random event that produces two things a single scaled float cannot carry: a possibly-larger number *and* a boolean the floating combat text must know to render the hit differently. ADR-0004 anticipated this exactly — "any richer offensive pipeline (crits, damage packets) has to replace the body of this one function" — so crit replaces the `scale_outgoing` seam rather than bolting a stat onto every skill.

**The outgoing seam returns a packet, not a float.** A new `DamagePacket` (`class_name DamagePacket extends RefCounted`, `skills/core/damage_packet.gd`) carries `amount: float`, `type: StatKeys.DamageType`, `is_crit: bool`. `StatsComponent` gains:

```gdscript
func roll_outgoing(base: float, type: StatKeys.DamageType) -> DamagePacket:
    var amount := scale_outgoing(base, type)          # existing deterministic dmg_<type> scaling
    var is_crit := randf() < clampf(get_stat(StatKeys.CRIT_CHANCE), 0.0, 1.0)
    if is_crit:
        amount *= maxf(1.0, get_stat(StatKeys.CRIT_MULTI))
    return DamagePacket.new(amount, type, is_crit)
```

`scale_outgoing` stays as the deterministic type-scaling step (unchanged body, still the ADR-0004 seam for `dmg_<type>` mods); `roll_outgoing` is the new single entry point every damage source calls. Crit is a **caster-level** roll (chance and multiplier are character stats, not per-damage-type), so it sits outside the per-type `scale_outgoing` rather than inside it. Both damage call sites — `DamageEffect` (instant) and `SpawnProjectileEffect` (stored, applied on collision) — call `roll_outgoing` exactly once; the packet is the one code path, so no site re-rolls or forgets the multiplier.

**Crit rolls when the packet is built.** For instant effects that is at hit; for projectiles it is at *spawn* — the projectile carries `is_crit` alongside `damage`, and its crit is decided at fire, not on contact. This is the simplest one-path model and fine for a fast-projectile platformer. Moving the roll to collision later is a contained change (carry the caster's crit stats on the projectile and roll in `_on_body_entered` instead of storing the result) — noted, not built.

**Resistance is untouched and still victim-side.** `mitigate_incoming` runs on the target after the packet arrives, so caster-side crit and victim-side resist compose in the correct order regardless of when crit rolled. `crit_chance` base 5% and `crit_multi` base 150% live as `base_stats` on characters; the reserved `StatKeys.CRIT_CHANCE`/`CRIT_MULTI` keys (already present) become live.

**The crit flag rides `damage_dealt` to the FCT.** `HealthComponent.apply_damage` gains a trailing `is_crit := false` parameter and forwards it: `Events.damage_dealt` becomes `(source, target, amount, type, is_crit)`. The combat-text spawner reads `is_crit` and the FCT node renders a crit distinctly (larger scale + a crit color). This is the cheapest dopamine in the genre and the reason the flag must survive the whole pipeline rather than being consumed at damage time. Extending the signal is a deliberate cross-cutting change; `is_crit` defaults false so any non-combat emitter (none today) and every existing test that ignores the tail parameter keep working.

## Considered Options

- **Roll crit inside `scale_outgoing` and keep the float return.** Rejected: the function is a stateless per-type multiply reused by both call sites and by tests as `base → float`; a hidden random roll inside it makes damage non-deterministic and gives no channel for the crit flag to reach the FCT.
- **A separate `crit_dealt` event parallel to `damage_dealt`.** Rejected: two events for one hit invites the spawner to double-render or the two to desync; one event with a flag is the single source of truth for "what just happened to this target."
- **Return a `Dictionary {amount, is_crit}`.** Rejected in favor of a typed `DamagePacket` — stringly-typed dictionaries resist refactoring and read poorly; a small RefCounted is the codebase's idiom (cf. `AbilitySlot`).

## Consequences

- `Events.damage_dealt`'s new arity touches every connected handler. Today that is the combat-text spawner and tests; all must accept the fifth parameter.
- Crit is non-deterministic, so tests exercise the boundaries: `crit_chance = 0.0` never crits, `crit_chance = 1.0` always crits, and an always-crit packet's `amount` equals `scale_outgoing × crit_multi`. No test asserts a specific outcome of an un-pinned `randf()`.
- Enemies crit too (ADR-0002 symmetry) — every character rolls against its own `crit_chance`; an enemy with the 5% base will occasionally crit the player, which is acceptable and free.
- `crit_multi` is clamped to a floor of 1.0 in the roll so a debuff can never make a "crit" deal *less* than a normal hit; the stat itself is uncapped upward.
