# Dispatch prompt — M0.2 Target selection

Preconditions: none — can start immediately. Note: touches the same
activation path as M0.1; if both run concurrently, expect a small rebase.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M0.2 — Target selection** from the Oathbond development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement. Mandatory;
   it defines the definition of done and the test workflow.
2. `docs/briefs/m0-02-target-selection.md` — the spec. Every design decision
   in it is final; if reality contradicts it, stop and report instead of
   improvising.
3. The `oathbond-skill-system` skill, then `FactionComponent`,
   `AbilityComponent._resolve_activation`, and the Targeting section of
   `CONTEXT.md`.

The task: make `Skill.Targeting.ENEMY` and `ALLY` actually resolve. A new
all-static `TargetSelection` utility (`skills/targeting/target_selection.gd`)
owns hostility rules and snap-to-cursor-with-fallback candidate selection
over the `&"characters"` scene group; `Skill` gains a `targeting_range`
export; `_resolve_activation` uses the resolver and fails with `&"no_target"`
(no mana spent, no cooldowns) when nothing is in range. The brief specifies
the exact function signatures, snap radius, and fallback semantics — follow
them literally.

Three things worth restating from the brief:

- This resolver becomes the **single source of truth for "who would I hit"**
  — the M0.5 highlight will preview it. Don't fold any of it into
  `AbilityComponent` in a way only the cast path can reach.
- `_resolve_activation` stays static and pure — the brief's decision 5
  describes the allowed shape.
- Existing `test_ability_component.gd` targeting tests assert the old
  `push_error` behavior via `[ExpectedError]` — rewrite them to the new
  contract; don't leave expected-error scaffolding aimed at errors that no
  longer fire.

This story owes documentation: **ADR-0013** (identity vs. relationships
split, group discovery, hostility-as-code rationale) and the **CONTEXT.md**
Targeting/Hostility updates the brief lists.

Done means: the brief's acceptance criteria each hold and are covered by GUT
tests (its "Test ideas" section sketches them, including the 9-pair
hostility table), the full suite is green with new test files verifiably
running, the ADR and CONTEXT.md updates are written, and the work is
committed on `feat/m0-02-target-selection`. Out of scope is binding: no line
of sight, no target-lock UI, no multi-target.
