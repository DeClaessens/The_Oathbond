# Player and enemies share one StatsComponent, in both damage directions

Any character — player or enemy — that can deal or receive scaled damage gets the identical `StatsComponent`, resolved by the fixed child name `StatsComponent`, rather than separate player-only and enemy-only stat systems. A caster's `scale_outgoing` and a victim's `apply_damage`/resistance are the same code path regardless of which side is which, so an enemy can carry a damage buff or a resistance exactly like a player can, and vice versa.

## Considered Options

A leaner enemy-only stats system (no move_speed/jump_velocity, since enemies don't need them today) was the obvious alternative. Rejected because it would fork the damage pipeline the moment an enemy needed a resistance or a buff — assumed to happen soon after enemies exist at all.
