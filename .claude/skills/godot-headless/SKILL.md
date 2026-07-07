---
name: godot-headless
description: >-
  Run, smoke-test, or validate the Oathbond Godot project outside the GUT
  suite. Use when the user wants to launch the game, verify a change works in
  the running app, parse-check a script, or after adding any new class_name
  script or imported asset (class-cache / import refresh).
---

# Godot headless & run

Godot is not on `PATH`. The binary is per-machine; check which exists:

```bash
# Windows binary, from WSL (path has a space — quote it)
GODOT="/mnt/c/Program Files (x86)/Godot/Godot_v4.6.2-stable_win64.exe"

# macOS
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
```

Run everything from the repo root so Godot picks up `project.godot`.

## Exit codes lie — judge by output

Godot exits `0` even when a script fails to parse. Never trust `$?`; grep
the output for `SCRIPT ERROR` / `Parse Error` instead. The known startup
boilerplate (`AccessibilityServer not declared`, the GUT/Godot
version-compatibility warning) is noise on this project — ignore those two,
flag everything else.

## Refresh the class cache / imports

**After adding any new `class_name` script, scene, or asset**, run once:

```bash
"$GODOT" --headless --import
```

Until this runs, headless invocations can't see the new class — GUT then
*silently skips* test files that reference it, and scripts that use it fail
to load. This is the single most common cause of a bogus "all tests passed".

## Parse-check a script (fast, no game launch)

```bash
"$GODOT" --headless --check-only -s res://path/to/script.gd
```

Prints nothing beyond the version banner on success; prints `SCRIPT ERROR:
Parse Error: ...` on failure (and still exits 0 — grep, don't test `$?`).
Only catches parse errors in that one file, not type errors across files —
the full import or a test run is the deeper check.

## Smoke-run the game headless

```bash
"$GODOT" --headless --quit-after 60
```

Boots `main.tscn`, runs 60 frames, exits. Startup `push_error`s and script
load failures print to stdout — a quiet run (banner only) means the scene
tree assembled cleanly. This catches broken scene references, missing
components, and `_ready()` errors that unit tests miss.

## Run the game windowed

From WSL the Windows binary opens a normal game window on the Windows side:

```bash
"$GODOT" --path . &
```

Run it in the background — it blocks until the window closes. Use this when
the user should see or play the change; use the headless smoke-run when you
just need to verify boot health yourself.

## Running the tests

That's the `godot-gut-tests` skill — use it, don't improvise GUT flags here.
