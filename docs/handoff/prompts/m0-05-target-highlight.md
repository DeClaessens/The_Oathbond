# Dispatch prompt — M0.5 Target highlight

Preconditions: **M0.2 (target selection) merged**; best run after M0.3 so a
real enemy exists to point at. Verify
`skills/targeting/target_selection.gd` exists before starting; if it
doesn't, stop and report.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M0.5 — Target highlight** from the Oathbond development
plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement. Mandatory;
   it defines the definition of done and the test workflow.
2. `docs/briefs/m0-05-target-highlight.md` — the spec. Every design decision
   in it is final; if reality contradicts it, stop and report instead of
   improvising.
3. The `oathbond-skill-system` skill, then `TargetSelection` and its ADR
   (0013), the player scene, and an existing `.of()`-style component for
   the resolution idiom.

The task: the entity an ENEMY cast would resolve to *right now* glows. A
presentational `HighlightComponent`
(`components/highlight/highlight_component.gd`, idempotent
`set_highlighted(on)`, modulate-brighten is an acceptable first pass) goes
on enemies and the Training Dummy; a `TargetPreviewComponent` on the player
re-resolves every `_process` and moves the glow on change. Preview range
comes from the first equipped ENEMY-targeted skill (slots 0–3); none
equipped → preview fully off. Also author the player's first ENEMY skill to
point with: `skills/library/spark.tres` (ENEMY, ~500px range, short
cooldown, one modest EMBER `DamageEffect`), learned and equipped — zero new
effect classes.

The single non-negotiable, verbatim from the brief: **the highlight is a
preview of the real resolver — one code path.** Call the same
`TargetSelection.find_enemy(...)` the cast uses; never implement hover via
`mouse_entered`/`input_pickable` or any second detection mechanism. A
highlight that can disagree with the cast is worse than none. Also:
`is_instance_valid()` before touching the previous target (despawn can free
it between frames), the highlight never feeds anything back into the cast
path, and `HighlightComponent` never decides *whether* to glow.

Done means: the brief's acceptance criteria each hold and are covered by GUT
tests (its "Test ideas" section sketches them — especially the
preview-vs-resolver property check and the glowing-target-dies case), the
full suite is green with new test files verifiably running, and the work is
committed on `feat/m0-05-target-highlight`. Out of scope is binding: no
tooltips/nameplates, no ally/neutral highlight styles, no controller aim.
