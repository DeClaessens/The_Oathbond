# Health is a Resource Pool owned by HealthComponent, not a Stat in StatsComponent

Current HP lived in `StatsComponent.base_stats["health"]` alongside genuinely composed Stats like `move_speed` and `dmg_fire` — and `apply_damage` already had to special-case it, mutating `base_stats` directly instead of going through the Flat/Add%/Mult% modifier pipeline every other Stat uses (`StatsComponent`'s own doc-comment flagged this as the one exception). That's because HP isn't actually a Stat: it has memory (it depletes and needs to stay bounded to `[0, max_health]`) instead of being a pure function of base + active Modifiers recomputed fresh on every read.

We're pulling current HP out into a new `HealthComponent`, which owns the depleting value and the `apply_damage(raw, type, source)` entry point. `Max Health` stays a Stat in `StatsComponent` (still buffable via the existing modifier system — a future Vitality-style buff works unchanged). Resist math stays in `StatsComponent` too, exposed as a new `mitigate_incoming(raw, type)` counterpart to the existing `scale_outgoing(base, type)`, so "how Modifiers turn one number into another" stays in one place regardless of direction; `HealthComponent` calls it, then debits its own pool.

## Considered Options

Keep HP as a Stat and make the new `HealthComponent` a pure observer (read `get_stat(HEALTH)`/`get_stat(MAX_HEALTH)`, redraw on `stat_changed`) — the original plan for this work, before revisiting during the grill. Rejected: it leaves the actual bug in place (HP is qualitatively different from every other Stat, and the codebase already had to work around that) and just adds a renderer on top instead of fixing the model.

## Consequences

- `StatsComponent.apply_damage` is deleted; `Events.damage_dealt` now emits from `HealthComponent.apply_damage`.
- `Projectile._on_body_entered` looks up `HealthComponent.of(body)` instead of `StatsComponent.of(body)`. Any future damage-dealing code must do the same — `StatsComponent` can no longer take damage on its own.
- Every character that can take damage now needs a `HealthComponent`, not just characters that want a visible bar. `HealthComponent` moves from "optional cosmetic addition" to load-bearing combat infrastructure.
- `StatKeys.HEALTH` and `Stat.HEALTH` are removed — `StatKeys` now only ever names true Stats. `StatKeys.MAX_HEALTH` / `Stat.MAX_HEALTH` are unaffected.
- `test/components/stats/test_stats_component.gd`'s `apply_damage` coverage moves to a new `test/components/health/test_health_component.gd`; the existing Fireball test (`test/library/test_fireball.gd`) is updated to hit a `HealthComponent`-bearing target instead of asserting on `StatsComponent.get_stat(HEALTH)`.
