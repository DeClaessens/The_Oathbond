# Implementation briefs

Fully-specified work packages: all design decisions are made in the brief, so
the implementer (Thomas, or an agent) starts with zero open questions. When a
brief and reality disagree mid-implementation, stop and re-plan rather than
improvising — these documents are the contract.

Staged here because `gh` is not installed in the WSL environment; once it is,
these should be published as GitHub issues (label `ready-for-agent`) per
`docs/agents/issue-tracker.md`.

The full development plan — every milestone as a tracker-ready epic with
stories — lives in `docs/plan/epics-and-stories.md`; these briefs are the
specs behind its M0 stories. Ready-to-paste dispatch prompts that hand each
brief to a coding agent live in `docs/handoff/`.

## M0 — Combat completeness

| # | Brief | Depends on |
|---|-------|------------|
| 01 | [Global cooldown](m0-01-global-cooldown.md) | — |
| 02 | [Target selection](m0-02-target-selection.md) | — |
| 03 | [First real enemy + AI](m0-03-enemy-ai.md) | 02 (and 01, trivially) |
| 04 | [XP & character levels](m0-04-xp-and-levels.md) | 03 (needs something to kill) |
| 05 | [Target highlight](m0-05-target-highlight.md) | 02 (best after 03) |
| 08 | [Proving-grounds level + follow camera](m0-08-level-and-camera.md) | 03 (Slime exists to place) |

M0 exit criterion (from `docs/VISION.md`): a play session where you fight,
die, and level. **All M0 briefs merged 2026-07-07** — see
`docs/plan/STATUS.md`.

## M1 — Persistence

| # | Brief | Depends on |
|---|-------|------------|
| 02 | [Character save/load](m1-02-character-save-load.md) | Epic M0 merged; ADR-0015 |

M1 exit criterion: quit and resume a character; the account file exists
even though only Bonds will use it later.

## Conventions that apply to every brief

- Spaces for indentation, never tabs (CLAUDE.md).
- New `class_name` scripts are invisible to headless test runs until
  `--headless --import` refreshes the global class cache — run it once after
  adding any, and confirm new test files actually appear in GUT's output
  before trusting "All tests passed" (they are silently skipped otherwise).
- New domain vocabulary goes into `CONTEXT.md`; architectural decisions get
  an ADR in `docs/adr/`.
- Test layout mirrors source under `test/`; see the `godot-gut-tests` skill.
