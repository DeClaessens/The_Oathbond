---
name: oathbond-briefs
description: >-
  Implement a work package from docs/briefs/ (or a story from the dev plan).
  Use when the user says to implement, pick up, or dispatch a brief/story
  (e.g. "implement m0-03"), or asks what's ready to build next.
---

# Implementing a brief

Briefs in `docs/briefs/` are fully-specified contracts: every design decision
is already made. The shared working agreement lives in
`docs/handoff/agent-onboarding.md` — **read it and the brief before writing
any code**; this skill routes, it does not restate them.

## Order of operations

1. Read the brief end to end, then `docs/handoff/agent-onboarding.md`.
2. Check dependencies: the table in `docs/briefs/README.md` and the wave
   order in `docs/handoff/README.md`. If a prerequisite isn't merged, stop
   and say so — don't build on an unmerged assumption.
3. Read the ADRs the brief cites, plus `CONTEXT.md` entries for its
   vocabulary. Load `oathbond-skill-system` if it touches skills/stats,
   `oathbond-character-assembly` if it touches entities/components.
4. Branch `feat/m0-0X-<slug>` — never commit to `main`.
5. Implement. **If reality contradicts the brief — an API doesn't exist, a
   named file moved, an invariant already broke — stop and report the
   contradiction instead of improvising.** A flagged stop is a success.
6. Test per `godot-gut-tests`; after any new `class_name`, refresh the class
   cache (`godot-headless`) and confirm new test files actually appear in
   GUT's output.
7. Definition of done: the checklist at the bottom of
   `agent-onboarding.md` — acceptance criteria each backed by a test, suite
   green, out-of-scope respected, CONTEXT.md/ADR duties done, committed on
   the branch with judgment calls noted.

## Authoring a new brief

That's design work, not implementation — planning-tier only. Use the
`oathbond-brief-authoring` skill.
