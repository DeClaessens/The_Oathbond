# Build — locked mock → Godot scene

Runs only after the verdict gate. Input: the winning variant file(s) and the
user's verdict sentence.

## 1. Blueprint

You write the blueprint — this is the design step, not delegable. Translate
the winning mock region by region through the palette into a node tree, then
add everything a mock cannot show:

- Scene root and script, following the project's window idiom (e.g. a
  `CanvasLayer` window with `bind(...)` / `is_open()` — copy the pattern of
  an existing panel, don't invent one).
- Signals in and out, which gameplay component binds, open/close and pause
  behavior, the input action and key.
- The data contract: where every displayed value comes from at runtime. No
  hardcoded mock data survives into the scene.
- Reuse: existing UI scenes/scripts the build must embed rather than fork.

Save as `ux-prototypes/<name>/BLUEPRINT.md`. Complete when every visible
region of the winning mock has a named node and a named data source.

## 2. Dispatch the builder

One haiku-class agent (Agent tool, `model: "haiku"`). Its prompt: the
blueprint verbatim, the winning mock's file path, and instructions to first
read the project's relevant skill files by path (scene-assembly conventions,
headless validation — in this repo, `.claude/skills/godot-headless/SKILL.md`
and the UI idioms of existing `ui/` scenes). One builder, one scene — if the
user wants parallel builds, each goes in its own worktree.

## 3. Validate

The builder must, before reporting done: refresh the import/class cache,
parse-check every new script, and smoke-run headless — judging by output
(`SCRIPT ERROR` / `push_error`), never exit code. Then you run the game
windowed so the user can open the screen next to the mock. Complete when the
smoke-run is clean **and** the user has seen the real screen match the mock.

## 4. Absorb and clean

Capture the verdict and the blueprint's key decisions somewhere durable —
the story's brief, an ADR, or the commit message. Then delete
`ux-prototypes/<name>/` — mocks rot. The Godot scene is real code, not a
prototype: it meets the project's normal bar (tests per project norms,
domain terms, no prototype shortcuts).
