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
root:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless -s addons/gut/gut_cmdln.gd -gexit
```

`-gexit` plus `.gutconfig.json`'s `should_exit` make it terminate with a
summary — no `-gdir`/`-gprefix` flags needed; the config file supplies them.
Green looks like `---- All tests passed! ----`; a failure prints the failing
assert and a non-passing total. This machine's zsh has no `timeout` command — run the
command bare, don't prefix it.

## Write

Tests mirror the source layout under `test/` (`test/stats/`, `test/core/`,
`test/library/`). Follow the existing conventions — read a sibling like
`test/stats/test_stats_component.gd` before adding one:

- `extends GutTest`; test functions are named `test_*`.
- Use `before_each` / `after_each` for shared setup; `assert_eq`, `assert_true`,
  etc. for checks.
- A `StatsComponent` under test must be named exactly `"StatsComponent"` and
  parented to its character node, because production code finds it via
  `StatsComponent.of(node)` (which looks up that exact child name). See
  `test_sprint.gd` for the pattern.
- Free what you `new()`: `add_child_autofree(node)` for tree nodes, or
  `after_each()` calling `.free()`.
- Load authored skills with `load("res://skills/library/<name>.tres")` rather
  than reconstructing them, so the test exercises the real asset.

Done when the new test appears in the run output and the suite is green.
