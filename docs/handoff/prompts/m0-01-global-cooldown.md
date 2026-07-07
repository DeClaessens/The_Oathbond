# Dispatch prompt — M0.1 Global cooldown

Preconditions: none — can start immediately.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M0.1 — Global cooldown** from the Oathbond development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement. Mandatory;
   it defines the definition of done and the test workflow.
2. `docs/briefs/m0-01-global-cooldown.md` — the spec. Every design decision
   in it is final; if reality contradicts it, stop and report instead of
   improvising.
3. The `oathbond-skill-system` skill, then `components/`'s AbilityComponent
   and the `Skill` resource it activates.

The task: a short global cooldown on `AbilityComponent` — any successful
cast briefly locks all slots. Movement skills (`sprint.tres`,
`super_jump.tres`) are exempt via a new `ignores_global_cooldown` flag on
`Skill`: they neither respect nor trigger the GCD. Failure surfaces as a new
`&"on_global_cooldown"` reason through the existing `skill_failed` signal,
checked in the exact order the brief's decision 3 specifies. The GCD starts
only on *successful* activation, and a new
`global_cooldown_started(duration)` signal announces it (no UI work — the
signal just has to exist).

Two invariants the brief calls out, worth restating:

- `_resolve_activation` stays a pure static function — pass `gcd_ready: bool`
  in; do not make it read component state.
- Edit the `.tres` skill assets load-mutate-save or in-editor, never rebuild
  them (ADR-0006).

Done means: the brief's acceptance criteria each hold and are covered by GUT
tests (the brief's "Test ideas" section sketches them), the full suite is
green with your new test files verifiably running, and the work is committed
on `feat/m0-01-global-cooldown`. The brief's out-of-scope list (skill-bar
visualization, cast times, per-skill GCD durations) is binding.
