# M0-04 — XP and character levels

*Depends on M0-03 (needs something to kill). Closes M0: fight, die, level.*

## Goal

Killing enemies grants experience; enough experience raises the character's
level; leveling makes the character durably stronger. The journey needs a
heartbeat before it can be the destination.

## Design decisions (made — do not reopen)

1. **`ExperienceComponent`** (`components/experience/experience_component.gd`)
   on the player: `level` (starts 1), current XP within the level, and
   signals `experience_changed(current: int, to_next: int)` and
   `leveled_up(new_level: int)`. Local signals, not `Events` — their only
   consumer for now is UI (the `Events` autoload is cross-cutting-only).
2. **It awards itself.** The component subscribes to
   `Events.character_died(victim, killer)` and grants XP when
   `killer == get_parent()`. No separate "XP system" node — the death event
   is already the cross-cutting part.
3. **Null killer = no XP.** This resolves the question ADR-0012 left open —
   amend that ADR's consequence bullet to record the answer (environmental
   deaths feed no one, and that's fine until some system needs otherwise).
4. **Rewards are data on the victim:** `XpRewardComponent`
   (`components/experience/xp_reward_component.gd`) with
   `@export var amount := 10`. Victim without one (or amount 0) grants
   nothing — the Training Dummy gets none on purpose; the Slime gets one.
   Not a stat: reward isn't modifiable by buffs, so it doesn't belong in
   `StatsComponent` (ADR-0009 reasoning, same shape).
5. **Kill attribution must survive projectiles.** The `source` on
   `apply_damage` must be the *casting character*, not the projectile node,
   or ranged kills credit no one. Verify `DamageEffect`/`Projectile` pass
   `ctx.caster` through; fix if not — that fix is in scope.
6. **Curve:** `xp_to_next(level) = roundi(50.0 * pow(level, 1.5))` as a
   tunable constant on the component. Overflow carries across level-ups and
   one large award can grant multiple levels (loop, don't clamp).
7. **Level-up payoff, M0 version:** permanent FLAT modifiers through the
   existing modifier system — `+10 max_health`, `+5 max_mana` per level
   (constants for now; per-class growth tables are M6 territory) — plus a
   **full restore of Health and Mana** (`restore_full()` on both pools; the
   classic level-up rush, and it sidesteps "max rose but current didn't"
   edge cases). Applying growth as modifiers keeps authored `base_stats`
   untouched and respects ADR-0001's composition formula.
8. **Levels do not persist yet.** Quit = gone, until M1 (save system).
   `ExperienceComponent`'s state (level, xp) is exactly the kind of
   character state M1 will serialize — keep it trivially serializable
   (ints, no node references).

## Invariants to respect

- Neutral-from-op, base-from-source (ADR-0001): growth is modifiers, never
  mutation of `base_stats`.
- Anything reviving/refilling pools goes through `restore_full()`
  (ADR-0012 latch rule) — the level-up heal included.
- Check how permanent `StatModifier`s stack (stacking policy) so 10 level-ups
  yield 10 stacked flat bonuses, not one refreshed one.

## Documentation this brief owes

- **CONTEXT.md**: entries for **Experience** (earned quantity, spent on
  nothing — fills toward the next Level; _avoid_: XP as a Stat) and
  **Level** (the character's permanent progression tier; source of growth
  modifiers). Note the null-killer rule under Death or Experience.
- **ADR-0012**: one-line amendment recording decision 3.

## Acceptance criteria

- Killing the Slime raises the player's XP by the Slime's reward amount;
  killing it with the ember bolt (projectile) credits identically.
- Reaching the threshold levels up: `leveled_up` fires, max health/mana rise
  by the growth constants, both pools are full.
- An award larger than one level's requirement grants multiple levels with
  correct carry-over.
- A death with `killer == null` changes nothing.
- The player killing *themselves* (if self-damage exists via future cursed
  fragments) — decide by test: `killer == victim` grants nothing (add the
  guard; it's two lines now and a exploit later otherwise).
- Full GUT suite green.

## Test ideas

- Emit `Events.character_died` with a victim carrying `XpRewardComponent`
  and `killer` = the component's parent → XP increases; `killer` = other
  node / null / the victim itself → unchanged.
- Award exactly `xp_to_next(1)` → level 2, XP back to 0, pools full,
  `get_stat(MAX_HEALTH)` up by 10.
- Award `xp_to_next(1) + xp_to_next(2) + 3` in one grant → level 3, 3 XP
  remaining.
- Ten level-ups → max health up by exactly 100 (stacking check).
- Integration: player + Slime scene, ember bolt kills Slime → player XP rose
  (attribution through the projectile, end to end).

## Out of scope

- XP bar UI — worth doing soon after (MapleStory's bar is iconic), but a
  separate slice; the `experience_changed` signal is its contract.
- Talent points, skill unlocks, or any other level-up reward beyond stats.
- Enemy levels / level-difference XP scaling (needs zones — M4).
- Rested XP, XP buffs, party bonuses (no party — ever, per VISION).
- Persistence (M1).
