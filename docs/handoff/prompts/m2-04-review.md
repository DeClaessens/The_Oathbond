# Review prompt — M2.4 Equip gate & slots + Character Screen

Preconditions: branch `feat/m2-04-equip-and-character-screen` exists with
commits `a0c8211` (implementation) + `89a8ef3` (design addendum). The story
was implemented by a coding agent on 2026-07-11 from the brief **plus a
design addendum** appended to it on the branch. Do NOT switch the main
checkout's branch (it carries in-flight M2.6 work); review the diff from the
repo root, and run tests/the game from a worktree with the branch checked
out (one already exists at `.claude/worktrees/agent-a968700d472fc302c`, or
make your own with `git worktree add`).

Copy everything below the line into a fresh review session at the repo root.

---

Review story **M2.4 — Equip gate & slots + Character Screen** before merge.
The branch under review is `feat/m2-04-equip-and-character-screen`; the diff
is `git diff main...feat/m2-04-equip-and-character-screen`. You are
reviewing, not fixing: report findings, don't push commits.

Read first, in this order (note: read the brief FROM THE BRANCH — it gained
a design addendum there):

1. `docs/handoff/agent-onboarding.md` — the working agreement.
2. `git show feat/m2-04-equip-and-character-screen:docs/briefs/m2-04-equip-gate-and-slots.md`
   — the spec, including the **Design addendum — Character Screen
   (2026-07-11)** section at the bottom. The addendum is part of the
   contract: it supersedes decision 8's "functional, not styled" panel and
   deliberately pulls item comparison + drag-to-equip INTO scope. Do not
   flag those as scope creep; DO flag anything beyond them (auto-equip,
   loadouts, sorting, stacking stay out).
3. `docs/adr/0016-derived-stats-one-way-table.md` and
   `docs/adr/0015-save-architecture.md` — the two ADRs this story leans on.
4. The `oathbond-skill-system` skill, then the changed code:
   `items/core/item_types.gd`, `components/equipment/`,
   `components/stats/stats_component.gd` (new `remove_by_source`),
   `save/` (validator + load order), `components/inventory/` (CAPACITY
   40 → 30 — a sanctioned decision, not a bug), `ui/character_screen/`
   (new; replaces the deleted `ui/inventory/`), `main.tscn`, and the new
   tests under `test/`.

Run the two review axes side by side, per project convention:

- **Spec axis** — the brief's acceptance criteria are the checklist; its
  "Design decisions" (1–7 unchanged, 8 as amended by the addendum) and the
  amended out-of-scope list are pass/fail. Any reopened decision or extra
  scope is a finding, not a style nit.
- **Standards axis** — agent-onboarding invariants, ADR conformance, code
  style (spaces, comment discipline), UI idioms matching
  `ui/skills_window/` (the reference window), tests following `test/`
  conventions.

The four places a defect would hurt most — verify each directly, in the
code and in the tests:

1. **Unequip symmetry**: `remove_by_source` must route through the
   ADR-0016 dependent-emission helper exactly once — a raw `_mods.erase`
   loop that skips dependent emission leaves max pools stale. The
   equip→unequip test must prove exact restoration including derived stats
   (`+Might` item restoring `max_health`).
2. **One legality gate**: `Equipment.validate` is called by the UI drop
   path AND by load; any second copy of slot-match or requirement logic
   (in a tile, in the validator, anywhere) is a review failure. The
   structural `SaveValidator` must NOT check legality (it has no stats).
3. **Load order**: equipment applies before health/mana clamp (the
   ADR-0015 hazard — the near-full-pool round-trip test is the proof), and
   the illegal-on-load item routes to inventory with a warning.
4. **UI mutates only through the component**: `ui/character_screen/` must
   never touch `_equipped`, apply `StatModifier`s itself, or re-derive
   drop legality — tiles call `equip`/`unequip`/`validate` and render
   results. Delta arithmetic lives only in the static `ItemCard.mod_deltas`
   (unit-tested).

Verification duties (from the worktree, never trust exit codes — grep
output for `SCRIPT ERROR` / `push_error`):

- `--headless --import` once, then the full GUT suite via the
  `godot-gut-tests` skill. Expect **361/361**; confirm the NEW test files
  actually appear in the run output (class-cache skips are silent).
- Headless smoke-run (`--headless --quit-after 60`): banner-only output.
- In-game check (windowed, `--path .` from the worktree): kill slimes →
  pick up drops → **I** opens the screen → hover shows the delta tooltip →
  click pins the card → drag equips (stats block moves) → click equipped
  unequips (stats restore) → `plate_helm` (requires Might 10) refuses with
  a reason line → two rings occupy Ring 1 then Ring 2 → quit via window
  close and relaunch: gear still equipped, stats match.

Known and accepted — do not report these:

- No pause/panel-stack coordination with SkillsWindow (accepted M2.6
  limitation, same wording in its brief).
- `main.tscn` will conflict with the unmerged `feat/m2-06-skills-window`
  branch; that's a merge-time concern, not a branch defect.
- Two test fixtures (`iron_ring`, `plate_helm`) added to the item catalog
  for gate coverage.

Report: findings ranked most-severe first, each with file:line, what the
brief/ADR/invariant it violates, and a concrete failure scenario — then a
bottom-line verdict: merge-ready, merge-ready-with-nits, or needs-work.
