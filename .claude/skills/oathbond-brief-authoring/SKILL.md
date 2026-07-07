---
name: oathbond-brief-authoring
description: >-
  Write an Oathbond implementation brief and its dispatch prompt. Use when a
  design pass is turning a planned story into a spec, when the user asks to
  "write a brief" / "spec out" a story, or when preparing the next
  milestone's stories for dispatch to coding agents.
---

# Authoring a brief

A brief is the contract a cheaper coding model implements without reopening
decisions. Its quality bar is absolute: **the implementer starts with zero
open questions.** Every "TBD", "probably", or unstated choice in a brief
becomes an improvisation downstream — the exact failure the pipeline exists
to prevent. Brief authoring is planning-tier work (Thomas or a
planning-tier model), never delegated to the implementing model.

## When a brief gets written — and when not

- A brief exists per **story** in `docs/plan/epics-and-stories.md`, written
  by its epic's design pass when the milestone nears. Until then the story
  stays `needs-info`; the brief's existence is what relabels it
  `ready-for-agent` (see the plan doc's import notes).
- **Not earlier.** VISION.md is direction, not contract — systems get their
  real design when their milestone starts. A brief written milestones ahead
  will be wrong by the time it's picked up.
- One brief = one story = one vertical slice, demoable or verifiable on its
  own and sized for a single agent session. If the decisions section wants
  to sprawl, split the story in the plan first.
- Design decisions that outlive the story (formulas, ownership, schemas) go
  to `docs/adr/`; new vocabulary goes to `CONTEXT.md`. The brief *cites*
  them — it never becomes their only home.

## Where it lives

1. `docs/briefs/<milestone>-<nn>-<slug>.md` — the spec.
2. A row in `docs/briefs/README.md`'s table, with its dependencies.
3. A dispatch prompt at `docs/handoff/prompts/<same-name>.md`.
4. Destination: a GitHub issue labeled `ready-for-agent` once `gh` exists
   (`docs/agents/issue-tracker.md`); write briefs as self-contained issue
   bodies — no reliance on "see above" context.

## The brief itself — sections in order (match the m0 files)

- **Goal** — what and *why*, linking the vision/design doc that motivates
  it. The implementer should understand what "done in spirit" means.
- **Design decisions (made — do not reopen)** — numbered. Each states the
  choice, the concrete shape (names, signatures, values, files), and one
  sentence of rationale so the decision survives contact with reality.
  Name exact identifiers (`&"on_global_cooldown"`, `ignores_global_cooldown`)
  — vagueness here is a decision delegated by accident.
- **Invariants to respect** — the ADRs and existing shapes this work must
  not break, each cited (`ADR-0003`), with the *trap* spelled out, not just
  the rule.
- **Acceptance criteria** — observable, testable statements. "Full GUT
  suite green" is always the last one.
- **Test ideas** — sketches, not prescriptions; enough that the implementer
  never wonders *how* to test a criterion.
- **Out of scope** — binding, not advisory. List the adjacent work a
  well-meaning implementer would be tempted to include.

Before freezing the decisions, stress-test them (the `grilling` skill is
built for this): every decision a reviewer could plausibly push back on
should already carry its rationale.

## The dispatch prompt

Mirror `docs/handoff/prompts/m0-01-global-cooldown.md`: a preconditions
header for the human (dependencies + "verify, stop if unmet"), then `---`,
then the pasteable body — reading order (onboarding agreement first, brief
second, relevant skills/code third), a short restatement of the task, the
two or three invariants most likely to be violated, and a "done means"
paragraph. The prompt summarizes; it never adds decisions the brief lacks.

Done when: brief and prompt exist and are linked from both READMEs, the
story's plan entry points at the brief, every design decision is closed, and
nothing in the brief contradicts CONTEXT.md, the ADRs, or the code as it is
*today* (verify against source, not memory).
