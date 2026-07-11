---
name: godot-ui-prototype
description: >-
  Mock a Godot game UI in throwaway HTML before building it. Use when the
  user wants to explore what an in-game window, HUD, or menu should look
  like, compare layout options before committing, or turn a decided mock
  into a real Control scene.
---

# Godot UI prototype

The loop: **mock → gallery → verdict → build**. Haiku-class subagents do all
generation — the HTML mocks now, the Godot scene later; you scope the
question, enforce structural difference, and hold the verdict gate. You never
write a mock or the scene yourself.

Why HTML first: a browser round-trip is seconds, a Godot scene round-trip is
minutes. Iterate in HTML until the design is locked, translate exactly once.

## The palette

Mocks may only use constructs that map 1:1 onto Godot Control nodes —
anything outside the palette can't be translated, so it poisons the verdict.
Inject this table verbatim into every mocker prompt:

| HTML/CSS | Godot |
|---|---|
| `display:flex` row / column | `HBoxContainer` / `VBoxContainer` |
| CSS grid, fixed column count | `GridContainer` |
| flex row with `flex-wrap` | `HFlowContainer` |
| centered box | `CenterContainer` / anchors |
| bordered/filled rounded box | `Panel` + `StyleBoxFlat` (bg, border, corner radius) |
| text, one style per element | `Label` (mixed inline styles = `RichTextLabel` — a decision, flag it) |
| `<button>` | `Button` |
| `<img>` / colored square tile | `TextureRect` / styled `Panel` |
| scrollable region | `ScrollContainer` |
| progress/resource bar | `ProgressBar` / `TextureProgressBar` |
| `<input type="range">` | `HSlider` |
| full-screen dim layer | full-rect backdrop `Control` on a `CanvasLayer` |
| hover state, `title=` tooltip | Control hover + built-in `tooltip_text` |

Banned in mocks: web fonts, external assets or CDN anything, backdrop
blur/filters, CSS animations beyond simple transitions, `position:sticky`.
Godot has no cheap equivalent, so a mock leaning on them overpromises.

## Phase 1 — Mock

1. **Scope the question.** One sentence: which screen, and what UX question
   the gallery must answer ("how should the loadout screen arrange slots vs
   library?"). No question, no mocks.
2. **Gather real context.** Read the viewport size from `project.godot`
   (`display/window/size`). Pull real data from the project — actual skill or
   item names, real counts, real keybinds — never lorem ipsum. Skim the
   project's existing UI scenes (`ui/` or equivalent) for the established
   look. Best backdrop is a gameplay screenshot (ask the user, or take one
   via the project's run skill); fallback is a flat dark rect at exact
   viewport size. A mock floating in a vacuum always looks fine — that's the
   trap.
3. **Dispatch mockers.** Three haiku-class agents (Agent tool,
   `model: "haiku"`) in parallel, one variant each, each writing its own
   self-contained file `ux-prototypes/<name>/variant-<a|b|c>.html`. Create
   the folder first with a `.gdignore` inside so the Godot editor never
   scans it. Each prompt carries: the question, the palette table verbatim,
   viewport size, the real data, the backdrop, and — the structural mandate —
   a distinct layout thesis you assign per agent (e.g. "grid of large
   tiles", "list + detail pane", "horizontal strip"). Variants must disagree
   about structure, not colour. One file per agent, never two agents in one
   file.
4. **Gallery.** Write `ux-prototypes/<name>/index.html` yourself: iframes
   the variants at viewport size, ←/→ keys and a corner label to switch.
   Open it for the user (on WSL: `explorer.exe` with the Windows path) and
   hand over — variant keys plus each one's one-line thesis.

Phase 1 is complete when the user has the gallery in front of them — not
when files exist.

## The verdict gate

The verdict is the user naming a winner — often a franken-mix ("header from
A, list from C"). Anything short of that sentence loops: dispatch a fresh
round of mockers refined by the feedback (new files; keep the old round for
comparison). Never substitute your own judgment of which variant is best —
the user's sentence is the gate, and it is the only artifact of phase 1
worth keeping.

Verdict locked → read [BUILD.md](BUILD.md).
