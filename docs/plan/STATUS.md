# Project status — single source of "where are we"

One page, always current. Any session (human or agent) starting work reads
this first instead of re-deriving state from git history. **Whoever merges a
story or closes a decision updates this file in the same commit.**

Last updated: 2026-07-08.

## Where we are

- **Milestone in progress: M1 — Persistence.** M0 (Combat completeness) is
  code-complete: all six implementation stories merged to `main` 2026-07-07,
  full GUT suite green (170/170 as of 2026-07-08).
- The M0 exit criterion — a play session where you fight, die, and level —
  is buildable in the proving-grounds level (`levels/`), with the Slime as
  the first real enemy.

## Story ledger

| Story | What | State |
|-------|------|-------|
| M0.1 | Global cooldown | ✅ merged 2026-07-07 (`b06aee8`) |
| M0.2 | Target selection | ✅ merged 2026-07-07 (`81125d6`) |
| M0.3 | First real enemy + AI (Slime) | ✅ merged 2026-07-07 (`ccaa243`) |
| M0.4 | XP & character levels | ✅ merged 2026-07-07 (`f198c17`) |
| M0.5 | Target highlight | ✅ merged 2026-07-07 (`a050de9`) |
| M0.6 | FIRE→EMBER rename | ✅ done 2026-07-06 |
| M0.7 | **Decision:** death penalty model | 🟡 open — `ready-for-human` (Thomas). VISION leans "keep cheap respawn"; record the call in VISION's open questions. |
| M0.8 | Proving-grounds level + camera | ✅ merged 2026-07-07 (`da6f2dd`) |
| M1.1 | Design pass: save architecture | ✅ done 2026-07-08 — ADR-0015 + `docs/briefs/m1-02-character-save-load.md` |
| M1.2 | Character save/load | 🔵 dispatched 2026-07-08 to a coding agent — branch `feat/m1-02-character-save-load`, awaiting review |
| M2+ | Loot, splicing, … | ⚪ not started — see `epics-and-stories.md` |

## Standing pointers

- Full story detail & acceptance criteria: `docs/plan/epics-and-stories.md`
- Specs/contracts for stories: `docs/briefs/`
- Dispatch prompts + agent working agreement: `docs/handoff/`
- Design backbone: `docs/VISION.md` · Domain language: `CONTEXT.md` · Decisions: `docs/adr/`

## Human queue (Thomas)

1. **M0.7 death-penalty decision** — the fight–die–level loop is playable;
   decide and close the VISION open question.
2. **Feel pass on M0** — GCD 0.4s cadence, Slime chase/bite tuning, camera
   feel. Tuned by play, not by test (`docs/handoff/README.md`).
