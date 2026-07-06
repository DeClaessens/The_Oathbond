# M0-03 — First real enemy: AI that fights through the skill system

*Depends on M0-02 (target selection).*

## Goal

The game's first enemy that fights back: detects the player, chases, and
attacks — where "attacks" means *casting a Skill through its own
`AbilityComponent`*, exactly like the player does. This is the proof of the
symmetric design (ADR-0002 spirit): enemies are characters assembled from
the same components, not a parallel system.

## Design decisions (made — do not reopen)

1. **Behavior is a component.** New
   `components/ai/ai_controller_component.gd`, `class_name
   AiControllerComponent`. A character without it just stands there (the
   Training Dummy keeps proving that composition works by *not* having one).
   The component drives its parent, which must be a `CharacterBody2D`.
2. **Three-state machine, nothing fancier:**
   - `IDLE` — no hostile within `@export var aggro_range := 400.0`.
   - `CHASE` — hostile detected: walk toward it at the parent's
     `MOVE_SPEED` stat (read via `get_stat` every frame — never cached),
     gravity applied like the player does.
   - `ATTACK` — hostile within the equipped skill's `targeting_range`:
     stop and call `abilities.activate(0, target.global_position)` — the
     aim point is the AI's "cursor" (M0-02's snap targeting then hits the
     chosen target exactly). Cooldowns (slot + global) pace the attack rate
     for free — the AI just tries every frame it's in range; failed
     activations are normal, not errors.
   Detection reuses `TargetSelection.find_enemy(...)` from the enemy's own
   perspective — the payoff of M0-02, zero new hostility logic.
3. **The first enemy is a new scene** under `entities/enemies/` (name it
   what you like — the brief calls it Slime): `CharacterBody2D` with
   `StatsComponent` (max_health, move_speed, dmg_physical),
   `FactionComponent` (ENEMY), `HealthComponent`,
   `DespawnOnDeathComponent`, `AbilityComponent`, `AiControllerComponent`,
   and a `CollisionShape2D`. The Training Dummy is untouched.
4. **The attack is authored data, not code.** A new
   `skills/library/slime_bite.tres`: `Targeting.ENEMY`, small
   `targeting_range` (~90px), modest cooldown (~1.2s), one `DamageEffect`
   (PHYSICAL). Zero new effect classes — if this enemy needs new code beyond
   the AI component, something is wrong.
5. **No jumping, no pathfinding, no leash.** The Slime walks along the
   ground toward the player's x-position and gives up (back to IDLE) when
   the player leaves `aggro_range`. Ledges, platforms above, and stuck
   states are accepted M0 jank — note them in the scene or a comment, don't
   solve them.

## Invariants to respect

- The AI calls `abilities.activate(index)` and *nothing lower* — it never
  builds a `SkillContext`, never touches effects, never applies damage
  directly. If the AI needs an ability the skill system can't express, the
  skill system gets the feature, not the AI.
- Movement reads `get_stat(StatKeys.MOVE_SPEED)` per frame (invariant 4 of
  the skill-system skill).
- `AbilityComponent.caster` must be set (see how `player.gd` does it) —
  the AI component's `_ready` is a sensible place to wire its parent.
- Component resolution via `.of()` / exact child names, per ADR-0007.

## Acceptance criteria

- Player walks within `aggro_range` → Slime chases; within bite range →
  player takes periodic physical damage (visible via Floating Combat Text
  and health bar, both already wired to `Events.damage_dealt`).
- Player kills the Slime → it despawns (existing `DespawnOnDeathComponent`).
- Slime kills the player → player respawns at spawn point; Slime returns to
  IDLE (the dead-then-respawned player re-triggers aggro naturally on next
  detection tick — dead characters are not targets per M0-02).
- Player leaves `aggro_range` → Slime stops chasing.
- Full GUT suite green.

## Test ideas

- Slime + player-faction body far apart → stays IDLE (velocity.x == 0).
- Within `aggro_range` → velocity.x sign points toward the target.
- Within bite range → `skill_activated` fires on the Slime's
  `AbilityComponent`; target's health drops.
- Kill the target → Slime back to IDLE, no activation attempts on a corpse.
- Slime scene instantiates with all components resolvable via `.of()`
  (guards against scene wiring regressions, like the dummy's test does).

## Out of scope

- Patrol routes, wander, leashing back to a spawn point.
- Multiple enemy archetypes, ranged enemies (the *system* supports them via
  a projectile skill — authoring one is a follow-up, not M0).
- Aggro/threat tables, de-aggro timers, alert states.
- Enemy skill bars/telegraphs (bosses will want telegraphs — M4).
