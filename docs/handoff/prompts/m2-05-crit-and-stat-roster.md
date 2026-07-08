# Dispatch prompt — M2.5 Crit & the new stat roster

Preconditions: M2.1 done and Epic M1 merged. Independent of M2.2/M2.3/M2.4
(parallel OK, any merge order). Verify ADR-0017 + the brief exist; stop if
not.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M2.5 — Crit & the new stat roster** from the Oathbond
development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement.
2. `docs/adr/0017-crit-in-outgoing-packet.md` — the mechanism you implement;
   it is the contract. Read `docs/adr/0004-outgoing-damage-scaled-from-skill-base.md`
   too (the seam crit replaces).
3. `docs/briefs/m2-05-crit-and-stat-roster.md` — the spec. Final; if reality
   contradicts it, stop and report.
4. The `oathbond-skill-system` skill, then `components/stats/
   stats_component.gd` (`scale_outgoing`), `skills/effects/damage_effect.gd`,
   `skills/projectile/projectile.gd`, `skills/core/ability_component.gd`
   (cooldown + mana spend), `components/health/health_component.gd` +
   `components/mana/mana_component.gd` (the regen pattern), the `Events` bus,
   and `vfx/floating_combat_text/`.

The task: implement ADR-0017 (the `DamagePacket`, `roll_outgoing`, crit from
`crit_chance`/`crit_multi`, the `is_crit` flag threaded to the FCT), add the
crit base stats to the player and Slime, and wire the four dormant stat keys
to consumers — flat/%-added damage (FLAT/ADD_PCT ops on `dmg_<type>`, no new
key), `health_regen` (a HealthComponent regen loop), `cooldown_reduction`
(per-skill cooldowns, not the GCD), and `mana_cost_reduction` (on spend).

Three invariants most likely to bite:

- **One `roll_outgoing` seam, crit flag survives to the FCT** (ADR-0017) —
  don't re-roll at two call sites; don't consume `is_crit` before the
  spawner. `scale_outgoing` stays the deterministic inner step (ADR-0004);
  crit sits *outside* it.
- **CDR touches per-skill cooldowns only, never the GCD** (M0.1's contract).
- Crit is random — test boundaries (chance 0 / chance 1) and the multiplier
  identity, never a specific `randf()` outcome. Enemies crit too (ADR-0002).

`Events.damage_dealt` gains a trailing `is_crit` param — update every
connected handler and test. New `class_name DamagePacket` ⇒ `--headless
--import` once; confirm new/changed tests appear.

Done means: the brief's acceptance criteria hold and are test-backed (crit
boundaries, flag threading, flat vs % damage, health regen, CDR/MCR with
caps and GCD untouched), the CONTEXT.md entries are written, the suite is
green with new tests verifiably running, committed on
`feat/m2-05-crit-and-stat-roster`. The out-of-scope list (pool authoring
beyond what its own test needs, DoT crit, attack speed/dodge/block, FCT
beauty, rebalancing) is binding.
