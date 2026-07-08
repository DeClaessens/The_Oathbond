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
wave 3:  M0.4 (XP & levels)      M0.5 (target highlight)      M0.8 (level & camera)
```

- **Wave 1** — M0.1 and M0.2 have no dependencies. They are independent in
  the plan but both touch `AbilityComponent`'s activation path (M0.1 adds
  the GCD check, M0.2 rewrites targeting resolution in
  `_resolve_activation`). Running them in parallel works but whichever
  merges second rebases; running them sequentially (either order) is the
  zero-friction option.
- **Wave 2** — M0.3 needs M0.2 merged.
- **Wave 3** — M0.4 needs M0.3; M0.5 needs M0.2 and is best after M0.3.
  M0.8 needs M0.3 (the Slime exists to place) and touches only scenes,
  `main.gd`, and a new `levels/` directory. All three touch disjoint areas
  and parallelize cleanly — except that M0.8 and any story rewire
  `main.tscn` positions; if run in parallel with M0.4/M0.5, merge M0.8
  last or first, not interleaved.

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
   the ADR-0012 amendment + CONTEXT.md Experience/Level entries; M0.8 owes
   ADR-0014 + CONTEXT.md Level (world) / Follow Camera entries.
4. **Feel** — GCD (0.4s) and the Slime's chase/bite are tuned by play, not
   by test. Run the game once before calling the story closed.

After merging, tick the story's boxes in `docs/plan/epics-and-stories.md`
(or close its issue once these live in GitHub — see
`docs/agents/issue-tracker.md`; `gh` is not installed yet).

## M1 and beyond

M1.1 (save-architecture design pass) is done 2026-07-08: ADR-0015, the
`m1-02-character-save-load` brief, and `prompts/m1-02-character-save-load.md`
exist — M1.2 is `ready-for-agent` and has no parallel siblings, so there is
no wave order to mind. Its review duties: ADR-0015 conformance (especially
"never serialize StatModifiers" and the fixed load order), the CONTEXT.md
entries the brief owes, and a real quit→relaunch resume check in the
running game.

M2.1 (Loot & inventory design pass) is done 2026-07-08: ADR-0016
(derived stats), ADR-0017 (crit), and briefs + prompts for M2.2–M2.5 exist.
All four are `ready-for-agent`.

## M2 dispatch order

```
wave 1:  M2.2 (attributes)   M2.3 (drops & inventory)   M2.5 (crit & stats)
                    │                    │
wave 2:             └────────┬───────────┘
                             │
                        M2.4 (equip gate)
```

- **Wave 1** — M2.2, M2.3, M2.5 are independent after M2.1 and touch mostly
  disjoint areas. Coordination points to watch when merging: all three add a
  section to the character save document and its validator (rebase whichever
  merges later); M2.2 and M2.4 both edit the save **load order**; M2.5's
  flat-damage test and M2.3's weapon affix pool reference the same
  `dmg_<type>` FLAT affix (M2.5 decision 4 says who adds it based on merge
  order).
- **Wave 2** — M2.4 needs M2.2 (attributes to require against) and M2.3
  (items to equip) both merged.

Each prompt's preconditions header repeats its dependency and tells the agent
to verify it and stop if unmet. Review duties per story: ADR conformance
(ADR-0016's dependent-emission for M2.2/M2.4; ADR-0017's single crit seam for
M2.5), the CONTEXT.md entries each brief owes, the save-document/validator
extension staying within the one-gate pattern, and a real in-game check
(allocate a point and watch a derived stat move; kill → drop → pick up →
equip → stat changes; land a visible crit).

M3+ implementation stories are `needs-info` until their epic's design pass
produces briefs (M3.1 is the next `ready-for-human` design story after M2).
When those briefs land, add a prompt here per story following the existing
pattern: preconditions header, reading list starting with
`agent-onboarding.md`, task summary that defers to the brief, restated
load-bearing invariants, story-specific definition of done.
