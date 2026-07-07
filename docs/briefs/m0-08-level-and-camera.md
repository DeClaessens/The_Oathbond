# M0-08 — Proving-grounds level + follow camera

*Depends on M0-03 (the Slime exists to place). No other M0 story depends on
this one.*

## Goal

Retire the single-slab test floor. The game gets its first real *level* —
still placeholder art, but several screens wide with a little verticality —
and a camera that follows the player, clamped to the level's bounds. This is
**not** M4 zone content (no identity, no art, no mastery): it's the sandbox
that makes M0's fight–die–level loop playable at more than one screen, and it
forces the camera/HUD/world-space seams to exist and be correct long before
M4.2 builds real zones on top of them (`docs/VISION.md` — "MapleStory-style
vertical maps").

Current reality this replaces: `main.tscn` instances a 1145px `Floor.tscn`
slab at the repo root; there is no `Camera2D` anywhere in the project; the
viewport is the project default 1152×648 (stretch `canvas_items`/`expand`).

## Design decisions (made — do not reopen)

1. **The camera is player-owned.** Add a `Camera2D` node (default name
   `Camera2D`) to `Player.tscn` with exactly:
   `position_smoothing_enabled = true`, `position_smoothing_speed = 8.0`,
   `limit_smoothed = true`, zoom untouched at 1. No script, no drag margins,
   no look-ahead. Rationale: in a solo game the player is the only thing the
   camera ever follows, so owning it in the Player scene gives every future
   level following for free; smoothing values are feel-tuned later, in play.
   Record the ownership split as **ADR-0014** ("the player owns the camera,
   the level owns its limits"), including the consequence that any future
   teleport (respawn, portals) must call `reset_smoothing()` or the camera
   will visibly pan across the whole level.
2. **Levels are scenes under `levels/`, and a level owns its bounds.** New
   script `levels/level.gd` — `class_name Level`, `extends Node2D`, one
   `@export var bounds: Rect2`. New scene
   `levels/proving_grounds/proving_grounds.tscn`, root `ProvingGrounds` (a
   `Level`). `main.tscn` instances it in place of the old `Floor` node, and
   `main.gd._ready()` copies `level.bounds` onto the player camera's
   `limit_left/top/right/bottom`. Rationale: clamping is per-level data; a
   one-export `Level` script is the smallest seam M4's real zones can grow
   from without inventing a level framework today.
3. **Bounds are the contract: `Rect2(0, -324, 4608, 972)`** — four screens
   wide, one and a half tall; bottom edge at y = 648, top at y = -324. The
   ground floor's walkable top edge sits at **y = 600** (the floor slab fills
   600…648). Geometry must fill the bounds: a full-width floor, and an edge
   wall at x = 0 and x = 4608 reaching from the floor to **at least y =
   -1024, i.e. ~700px past the top bound**. The camera never shows above
   -324, but a Super Jump launched *from the high ledge* (500 + 625px of
   apex, per decision 4) crests the sky line — a wall that stops at the
   bound would let the player drift over it off-screen and fall out of the
   world. Overshooting the walls costs nothing; leave them tall.
4. **Platforms obey the jump math.** With `default_gravity = 2948.2` and
   `jump_velocity = 800`, a normal jump's apex is v²/2g ≈ **108px**; Super
   Jump (+140% multiplicative, ADR-0001 → ×2.4 velocity) reaches ≈ **625px**.
   Author: a stepped route of 3–5 platforms with rises of **≤ 90px** each
   (comfortably normal-jumpable), plus **one high ledge 350–500px above the
   floor** — reachable only under Super Jump, so the level dogfoods the
   movement skill. Platforms are ≥ 200px wide (the player body is 127px) and
   every platform's `CollisionShape2D` sets `one_way_collision = true` so the
   player jumps up through and lands. Floor and walls stay two-way.
5. **All static geometry is `StaticBody2D` on collision layer 1 (World)
   only** (ADR-0008), inside the level scene. `Floor.tscn` at the repo root
   is deleted (`git rm`) after migration — `main.tscn` is its only user.
6. **Entity placement in `main.tscn`** (the level scene stays entity-free —
   geometry only, so M4 can decide separately where spawning lives): player
   spawn near the left edge (x ≈ 250), TrainingDummy close by (x ≈ 650) to
   keep the firing-range dogfood, and **three Slimes** on the ground at
   x ≈ 1600, 2800, 4200 — at least 1100px apart, i.e. > 2× the 400px
   `aggro_range`, so encounters happen one at a time. No enemies on
   platforms: the AI has no pathfinding (m0-03 decision 5's accepted jank)
   and a slime walking off a ledge reads as a bug, not charm.
7. **Placeholder visuals stay placeholder.** Flat `ColorRect`s /
   `PlaceholderTexture2D` rects, at most distinct flat colors so floor,
   walls, and platforms read as different things. Art direction is an open
   VISION question; do not spend on it.

## Invariants to respect

- **ADR-0008** — every static body in the level is on layer 1 (World) and
  nothing else. The trap: a platform accidentally on layer 2/4 silently
  changes what projectiles hit and what the Slime collides with; the layer-1
  test below exists to catch exactly this.
- **HUD stays in a `CanvasLayer`.** `SkillBarHUD` already is one — don't
  reparent it under a world node "to tidy the tree", or the moving camera
  drags it away.
- **Floating Combat Text is world-space by design** — the spawner sets
  `global_position` on each instance. Do not "fix" it into a `CanvasLayer`:
  with a moving camera the number must stay at the victim, not on the screen.
- **`player.gd` is untouched.** The camera is scene-authored data plus a few
  lines in `main.gd`; movement/jump code already reads stats per frame
  (skill-system invariant) and needs no changes for this story.
- Component resolution and scene wiring conventions per ADR-0007 — the
  existing wiring tests (dummy, slime) show the pattern for the new scene
  test.

## Acceptance criteria

- Running the game: the camera follows the player on both axes with visible
  smoothing; walking to either end of the level, the view clamps at the
  bounds — no void beyond the walls, floor, or sky line is ever shown.
- The player can traverse the full 4608px width; edge walls stop them; the
  stepped platforms can be entered from below and landed on (one-way); the
  high ledge is reachable with Super Jump active and demonstrably not
  without it.
- The Slimes aggro, chase, and bite at their new positions; the dummy takes
  hits; Floating Combat Text appears at entities everywhere in the level;
  the skill bar never moves on screen. (All regression — no combat code
  changes.)
- `Floor.tscn` no longer exists; the level lives at
  `levels/proving_grounds/proving_grounds.tscn` with root class `Level`.
- ADR-0014 recorded; `CONTEXT.md` gains **Level** and **Follow Camera**
  entries under a new "World" section. Mind the vocabulary collision: M0.4
  introduces character *levels* (XP). The world entry defines Level as the
  engine container a zone is built from (geometry + bounds — a Zone, come
  M4, is a Level with identity), explicitly disambiguates it from Character
  Level, and lists *Avoid: map, stage*.
- Full GUT suite green, new test files verifiably running.

## Test ideas

- `Player.tscn` instantiates with a `Camera2D` whose
  `position_smoothing_enabled` and `limit_smoothed` are true (guards scene
  regressions, like the dummy wiring test does).
- `proving_grounds.tscn` instantiates: root is a `Level`; `bounds` equals
  the contract Rect2; every `StaticBody2D` descendant has
  `collision_layer == 1`.
- Platform `CollisionShape2D`s have `one_way_collision == true`; the floor
  and edge walls have it false.
- Main-scene wiring: after `_ready`, the player camera's four `limit_*`
  values equal the level bounds' edges.
- Reachability (apex ≈ 108 vs 625px) is verified by play, not GUT — one
  headless boot + a manual run per the `godot-headless` skill.

## Out of scope

- Zone identity: art, tilesets, parallax backgrounds, lighting, ambience —
  M4.2's whole job.
- Multiple levels, level transitions, portals, spawn-point/respawn systems
  (the `reset_smoothing()` consequence is *noted* in ADR-0014, not built).
- Enemy spawners or respawning enemies; enemy pathfinding/leash fixes.
- Camera features beyond the two smoothing flags: zoom controls, drag
  margins, look-ahead, screen shake, deadzones.
- Kill planes, pits, fall damage.
- Minimap or any new HUD.
