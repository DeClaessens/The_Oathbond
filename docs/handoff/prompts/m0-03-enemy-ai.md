# Dispatch prompt — M0.3 First real enemy + AI

Preconditions: **M0.2 (target selection) merged** — this story reuses
`TargetSelection` and ENEMY-targeted skill resolution. Verify
`skills/targeting/target_selection.gd` exists before starting; if it
doesn't, stop and report.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M0.3 — First real enemy + AI** from the Oathbond
development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement. Mandatory;
   it defines the definition of done and the test workflow.
2. `docs/briefs/m0-03-enemy-ai.md` — the spec. Every design decision in it
   is final; if reality contradicts it, stop and report instead of
   improvising.
3. The `oathbond-skill-system` skill, then `TargetSelection`,
   `AbilityComponent`, the player scene/script (for how `caster` is wired
   and how movement applies gravity), and the Training Dummy scene (the
   component-assembly reference).

The task: the game's first enemy that fights back — a Slime scene under
`entities/enemies/` assembled purely from existing components plus one new
`AiControllerComponent` (`components/ai/ai_controller_component.gd`) with a
three-state IDLE/CHASE/ATTACK machine. It detects via
`TargetSelection.find_enemy(...)` from its own perspective and attacks by
calling `abilities.activate(0, target.global_position)` — the aim point is
its "cursor". Its bite is authored data: `skills/library/slime_bite.tres`
(ENEMY targeting, ~90px range, ~1.2s cooldown, one PHYSICAL `DamageEffect`).

The load-bearing invariant: **the AI calls `abilities.activate()` and
nothing lower.** It never builds a `SkillContext`, never touches effects,
never applies damage directly. Zero new SkillEffect subclasses — if the
enemy seems to need new code beyond the AI component, something is wrong:
stop and report. Failed activations (cooldown, GCD, out of range) are
normal pacing, not errors. Movement reads `get_stat(StatKeys.MOVE_SPEED)`
every frame, never cached. No jumping, no pathfinding, no leash — the
brief's decision 5 lists the accepted M0 jank; note it, don't solve it.

Done means: the brief's acceptance criteria each hold (chase/bite/despawn/
respawn round-trip works in the scene, and the "Test ideas" cases are GUT
tests, including the scene-wiring `.of()` resolution test), the full suite
is green with new test files verifiably running, and the work is committed
on `feat/m0-03-enemy-ai`. Out of scope is binding: no patrols, no ranged
enemies, no threat tables, no telegraphs.
