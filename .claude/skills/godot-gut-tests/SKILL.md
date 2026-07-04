---
name: godot-gut-tests
description: >-
  Run and write the Oathbond GdScript test suite (GUT, headless Godot). Use
  when the user wants to run the tests, verify a change to the skill/stat
  system, or add a test under test/.
---

# Godot GUT tests

The suite is GUT (`addons/gut/`), configured by `.gutconfig.json`: it runs
everything under `res://test/`, files prefixed `test_`, and exits on completion.

## Run

Godot is not on `PATH`. Invoke the app binary directly, headless, from the repo
root. The binary location is per-machine — check which of these exists before
asking the user:

```bash
# macOS
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gexit

# Windows, including from WSL (path has a space — quote it)
"/mnt/c/Program Files (x86)/Godot/Godot_v4.6.2-stable_win64.exe" --headless -s addons/gut/gut_cmdln.gd -gexit
```

`-gexit` plus `.gutconfig.json`'s `should_exit` make it terminate with a
summary — no `-gdir`/`-gprefix` flags needed; the config file supplies them.

To run one file instead of the whole suite (cheaper while iterating), add
`-gselect=<substring>` matched against script filenames — `-gtest=res://...`
looks like the right flag but is a no-op here, since `.gutconfig.json`'s `dirs`
still wins and the full suite runs anyway:

```bash
-gselect=test_stats_component
```

### Reading the output

Every run — pass or fail — starts with a `SCRIPT ERROR: ... AccessibilityServer
not declared` parse error and ends with `This version of GUT may not be
compatible with Godot 4.6.2`. Both are startup boilerplate from the
GUT 9.7/Godot 4.6.2 version gap on this project, not a sign anything broke.
Ignore them; judge the run by the `Run Summary` block instead.

A real failure shows as `Passing Tests` less than `Tests` in that summary, or
the run ending without `---- All tests passed! ----`. Tests that assert an
expected error (`test_ability_component.gd`'s targeting tests) intentionally
print a red `ERROR:` line followed by `[ExpectedError] Expected push_error
error containing '...'` right after it — that pairing is a pass, not a
failure; only flag an `ERROR:` line that has no matching `[ExpectedError]`
directly below it.

## Write

Tests mirror the source layout under `test/` (`test/components/<x>/`,
`test/core/`, `test/library/`, `test/ui/`, `test/vfx/`). Follow the existing
conventions — read a sibling like `test/components/stats/test_stats_component.gd`
before adding one:

- `extends GutTest`; test functions are named `test_*`.
- Use `before_each` / `after_each` for shared setup; `assert_eq`, `assert_true`,
  etc. for checks.
- A `StatsComponent` under test must be named exactly `"StatsComponent"` and
  parented to its character node, because production code finds it via
  `StatsComponent.of(node)` (which looks up that exact child name). See
  `test/library/test_sprint.gd` for the pattern.
- Free what you `new()`: `add_child_autofree(node)` for tree nodes, or
  `after_each()` calling `.free()`.
- Load authored skills with `load("res://skills/library/<name>.tres")` rather
  than reconstructing them, so the test exercises the real asset.

Done when the new test appears in the run output and the suite is green.
