# Handoff — dispatching M0 to coding agents

How to hand the open M0 stories (`docs/plan/epics-and-stories.md`) to
implementation models. Working agreement: planning-tier models and Thomas
produce designs and briefs; implementation goes to cheaper coding models.
The briefs in `docs/briefs/` are the contract; these files are the wrapper
that gets an agent from a cold start to working inside that contract.

## What's in this directory

- `agent-onboarding.md` — the shared working agreement every implementing
  agent reads first: hard invariants, test workflow, git conventions, and
  the universal definition of done. Every prompt points here, so prompts
  stay short and this file stays the single place to update rules.
- `prompts/m0-0X-*.md` — one dispatch prompt per open story. Each file has
  a preconditions header for you, then a `---`; paste everything **below
  the line** into a fresh coding session started at the repo root.

## Dispatch order

```
wave 1:  M0.1 (GCD)          M0.2 (target selection)
                                  │
wave 2:                      M0.3 (enemy AI)
                                  │
wave 3:  M0.4 (XP & levels)      M0.5 (target highlight)
```

- **Wave 1** — M0.1 and M0.2 have no dependencies. They are independent in
  the plan but both touch `AbilityComponent`'s activation path (M0.1 adds
  the GCD check, M0.2 rewrites targeting resolution in
  `_resolve_activation`). Running them in parallel works but whichever
  merges second rebases; running them sequentially (either order) is the
  zero-friction option.
- **Wave 2** — M0.3 needs M0.2 merged.
- **Wave 3** — M0.4 needs M0.3; M0.5 needs M0.2 and is best after M0.3.
  M0.4 and M0.5 touch disjoint areas and parallelize cleanly.

Each prompt's preconditions header repeats its dependency and tells the
agent to verify it (and stop if unmet), so a mis-dispatched story fails
loudly rather than improvising.

Not dispatched: **M0.6** (FIRE→EMBER rename) is done; **M0.7** (death
penalty decision) is `ready-for-human` — yours, after M0.4 makes the
fight–die–level loop playable.

## Reviewing a finished story

When an agent reports done, before merging its branch:

1. **Brief conformance** — `/code-review` against the story's brief; the
   acceptance criteria are the checklist, and the "Design decisions" and
   "Out of scope" sections are pass/fail (any reopened decision or extra
   scope is a finding, not a style nit).
2. **Tests really ran** — check the GUT `Run Summary` and confirm the new
   test files appear in the output; new `class_name` scripts silently skip
   their tests until `--headless --import` refreshes the class cache.
3. **Docs duties** — M0.2 owes ADR-0013 + CONTEXT.md updates; M0.4 owes
   the ADR-0012 amendment + CONTEXT.md Experience/Level entries.
4. **Feel** — GCD (0.4s) and the Slime's chase/bite are tuned by play, not
   by test. Run the game once before calling the story closed.

After merging, tick the story's boxes in `docs/plan/epics-and-stories.md`
(or close its issue once these live in GitHub — see
`docs/agents/issue-tracker.md`; `gh` is not installed yet).

## M1 and beyond

M1+ implementation stories are `needs-info` until their epic's design pass
produces briefs (M1.1 is the next `ready-for-human` story after M0). When
those briefs land, add a prompt here per story following the existing
pattern: preconditions header, reading list starting with
`agent-onboarding.md`, task summary that defers to the brief, restated
load-bearing invariants, story-specific definition of done.
