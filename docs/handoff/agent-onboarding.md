# Onboarding — implementation agents

You are implementing one story of the Oathbond development plan
(`docs/plan/epics-and-stories.md`). This file is the shared working agreement;
the story's brief in `docs/briefs/` is the spec. Read both before writing code.

## The one rule that overrides everything

**The brief is the contract.** Every design decision in it is already made —
do not reopen, "improve", or work around them. If reality contradicts the
brief (an API doesn't exist, an invariant already broke, a named file moved),
**stop and report the contradiction** instead of improvising. A wrong-but-
flagged stop is a success; a silently improvised deviation is a failure.

## Project snapshot

- Godot 4.6.2, GDScript, component-based architecture: entities under
  `entities/`, reusable components under `components/`, authored skill assets
  (`.tres`) under `skills/`, UI under `ui/`, tests under `test/`.
- Domain vocabulary lives in `CONTEXT.md` at the repo root; architectural
  decisions in `docs/adr/`. Read the ADRs your brief cites.
- Two project skills exist and are mandatory reading when relevant:
  - `oathbond-skill-system` — before touching Skill / SkillEffect /
    StatModifier / AbilityComponent / StatsComponent or any `.tres` skill asset.
  - `godot-gut-tests` — before running or writing tests.

## Hard invariants (from ADRs — violating these fails review)

- No runtime state on Resources (ADR-0003). Skills and effects are data;
  state lives on components.
- Stat enum entries are append-only; enum order never changes (ADR-0005,
  ADR-0011).
- Authored `.tres` assets are migrated in place — load, mutate, save; never
  rebuilt from scratch (ADR-0006).
- Enemies and the player use the same components symmetrically (ADR-0002);
  never special-case "the player" inside a component.
- Failure reasons are `StringName`s in the existing style
  (`&"on_cooldown"`, `&"insufficient_mana"`).

## Code style

- Spaces for indentation, never tabs (CLAUDE.md).
- Match the existing code's naming, comment density, and idiom. No
  narration comments ("now we check X").

## Testing

- The suite is GUT, run headless. Godot is not on `PATH`; from the repo root:

  ```bash
  # Windows binary from WSL (path has a space — quote it)
  "/mnt/c/Program Files (x86)/Godot/Godot_v4.6.2-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gexit
  ```

  Add `-gselect=<filename substring>` to run one file while iterating.
- **After adding any new `class_name` script, run
  `--headless --import` once** — new classes are invisible to headless runs
  until the global class cache refreshes, and their test files are *silently
  skipped*. Confirm your new test files actually appear in GUT's output
  before trusting "All tests passed".
- Every run prints a startup `SCRIPT ERROR: ... AccessibilityServer` parse
  error and ends with a GUT/Godot version-compatibility warning. Both are
  boilerplate — judge the run only by the `Run Summary` block.
- A red `ERROR:` line immediately followed by `[ExpectedError] ...` is a
  passing expected-error assertion, not a failure.
- Tests mirror the source layout under `test/`. Read a sibling test file
  (e.g. `test/components/stats/test_stats_component.gd`) and follow its
  conventions.

## Documentation duties

- New domain vocabulary → an entry in `CONTEXT.md`.
- Architectural decisions the brief asks for → an ADR in `docs/adr/`,
  numbered sequentially, matching the existing files' format.

## Git workflow

- Work on a feature branch: `feat/m0-0X-<slug>` (e.g.
  `feat/m0-01-global-cooldown`). Do not commit to `main`.
- Conventional-commit style messages (`feat:`, `test:`, `docs:`), matching
  the existing history. Commit when the definition of done is met; do not
  push or open a PR unless asked.

## Definition of done (applies to every story)

1. Every acceptance criterion in the brief is demonstrably met, each backed
   by a test where testable.
2. Full GUT suite green — and new test files verifiably ran (see above).
3. The brief's "Out of scope" list was respected — nothing extra built.
4. Documentation duties done (CONTEXT.md / ADR, when the brief names them).
5. Work committed on the feature branch with a summary of what was built,
   any judgment calls made, and anything that surprised you.
