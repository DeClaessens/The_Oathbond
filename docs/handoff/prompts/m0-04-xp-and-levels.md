# Dispatch prompt — M0.4 XP & character levels

Preconditions: **M0.3 (enemy AI) merged** — this story needs the Slime to
kill and reward. Verify `entities/enemies/` contains it before starting; if
not, stop and report.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M0.4 — XP & character levels** from the Oathbond
development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement. Mandatory;
   it defines the definition of done and the test workflow.
2. `docs/briefs/m0-04-xp-and-levels.md` — the spec. Every design decision in
   it is final; if reality contradicts it, stop and report instead of
   improvising.
3. The `oathbond-skill-system` skill, then `docs/adr/0012-*` (death
   handling — you will amend it), `Events.character_died`, the
   StatModifier stacking policy, and `HealthComponent`/`ManaComponent`
   `restore_full()`.

The task: kills award XP, XP raises levels, levels grant durable strength.
Two new components under `components/experience/`: `ExperienceComponent` on
the player (level, in-level XP, `experience_changed` / `leveled_up` local
signals, self-awarding by subscribing to `Events.character_died` and
checking `killer == get_parent()`), and `XpRewardComponent` as data on
victims (Slime gets one, Training Dummy pointedly doesn't). Curve, growth
constants (+10 max_health / +5 max_mana per level as permanent FLAT
modifiers), full restore on level-up, and multi-level overflow are all
pinned in the brief — implement them exactly.

Load-bearing details from the brief:

- **Kill attribution must survive projectiles**: verify `DamageEffect` /
  `Projectile` pass `ctx.caster` as the damage source so ranged kills
  credit the caster — fixing that is in scope if broken.
- Guards: `killer == null` and `killer == victim` award nothing.
- Growth is modifiers, never mutation of `base_stats` (ADR-0001); the
  level-up heal goes through `restore_full()` (ADR-0012 latch rule); check
  the stacking policy so ten level-ups stack ten flat bonuses.
- Keep component state trivially serializable (ints, no node refs) — M1
  will persist it. But no persistence now.

This story owes documentation: **CONTEXT.md** entries for Experience and
Level (with the null-killer rule) and a one-line **ADR-0012 amendment**
recording that null killers feed no one.

Done means: the brief's acceptance criteria each hold and are covered by GUT
tests (its "Test ideas" section sketches them, including the end-to-end
projectile-attribution integration test), the full suite is green with new
test files verifiably running, the docs duties are done, and the work is
committed on `feat/m0-04-xp-and-levels`. Out of scope is binding: no XP bar
UI, no talent points, no level scaling, no persistence.
