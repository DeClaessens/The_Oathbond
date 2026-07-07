# Dispatch prompt — M0.8 Proving-grounds level + follow camera

Preconditions: M0.3 merged — `entities/enemies/slime/Slime.tscn` exists and
a placed Slime chases and bites. Verify before dispatching; the agent is
told to stop if unmet.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M0.8 — Proving-grounds level + follow camera** from the
Oathbond development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement. Mandatory;
   it defines the definition of done and the test workflow.
2. `docs/briefs/m0-08-level-and-camera.md` — the spec. Every design decision
   in it is final; if reality contradicts it, stop and report instead of
   improvising.
3. The `oathbond-character-assembly` skill (scene/`.tscn` editing and
   collision-layer conventions) and the `godot-headless` skill (you'll need
   an import refresh after adding the new `class_name Level` script, and a
   boot check at the end).

Precondition check before writing anything: `Slime.tscn` exists and
`main.tscn` currently instances `res://Floor.tscn`. If either is false,
stop and report.

The task: replace the single-slab test floor with a real placeholder level
and give the game its first camera. A `Camera2D` goes into `Player.tscn`
(smoothing on, speed 8.0, `limit_smoothed`, nothing else); a new
`levels/level.gd` (`class_name Level`) exposes one `@export var bounds:
Rect2`; `levels/proving_grounds/proving_grounds.tscn` authors the geometry
(full-width floor, edge walls, a normal-jump platform route, one
Super-Jump-only ledge — the brief's decision 4 has the exact jump math);
`main.gd` copies the level's bounds onto the camera's limits. `main.tscn`
places the player, the dummy, and three well-separated Slimes per decision
6, and `Floor.tscn` is deleted. The implementer also records ADR-0014 and
two `CONTEXT.md` entries per the brief.

Three invariants worth restating from the brief:

- Every static body in the level sits on collision layer 1 (World) and
  nothing else (ADR-0008) — a mis-layered platform silently corrupts
  projectile and AI collision.
- `SkillBarHUD` stays a `CanvasLayer` and Floating Combat Text stays
  world-space — do not "fix" either for the moving camera.
- `player.gd` is untouched; the camera is scene data plus a few lines in
  `main.gd`.

Done means: the brief's acceptance criteria each hold and are covered by GUT
tests (the brief's "Test ideas" section sketches them — remember
`--headless --import` after adding the `Level` class or its tests silently
skip), the full suite is green with the new test files verifiably running,
one headless boot passes, and the work is committed on
`feat/m0-08-level-and-camera`. The brief's out-of-scope list (zone art,
transitions, spawn systems, camera extras, kill planes) is binding.
