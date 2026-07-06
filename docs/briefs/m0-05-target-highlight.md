# M0-05 — Target highlight: showing who you'd hit

*Depends on M0-02 (target selection). Best implemented after M0-03 so there
is a real enemy to point at.*

## Goal

The entity an ENEMY cast would resolve to right now glows. With snap-to-
cursor plus nearest-to-caster fallback (M0-02), the contract with the player
is: **whatever glows is what you'll hit, and something always glows if a
cast would succeed.** No glow anywhere = the cast would fail `&"no_target"`.

## Design decisions (made — do not reopen)

1. **The highlight is a preview of the real resolver — one code path.**
   Player-side code calls the *same* `TargetSelection.find_enemy(...)` the
   cast uses, every frame, with the live mouse position, and highlights the
   returned node. Never implement hover via `mouse_entered`/`input_pickable`
   or any second detection mechanism — two code paths disagree at the edges
   and the highlight starts lying, which is worse than no highlight.
2. **`HighlightComponent`** (`components/highlight/highlight_component.gd`):
   purely presentational, opt-in per character (ADR-0007 style, resolved via
   a static `.of()` like its siblings). API: `set_highlighted(on: bool)`,
   idempotent. Visual: an outline shader on the parent's sprite is the good
   version; a simple modulate brighten is an acceptable first pass — the
   component's API hides the choice, so upgrading later touches one file.
   A character *without* the component is still perfectly targetable — it
   just doesn't glow. Every real enemy scene should carry one; the Training
   Dummy gets one too (it's the firing-range test subject).
3. **`TargetPreviewComponent`** on the Player scene owns the loop: each
   `_process`, resolve the would-be target, and on change flip the old
   target's highlight off and the new one's on. Use `is_instance_valid()`
   before touching the previous target — despawn can free it between frames.
4. **Preview range = the `targeting_range` of the first equipped
   ENEMY-targeted skill** (scan slots 0–3). No ENEMY skill equipped → no
   preview, no glow. With one ENEMY skill equipped — the M0 reality — the
   preview is *exact*. Multiple ENEMY skills with different ranges make the
   single highlight approximate for the others; that's a known, accepted M0
   simplification (note it in the component's doc comment; a future
   per-skill preview on key-hold can fix it if it ever matters).
5. **The player needs an ENEMY-targeted skill to point with.** Author one:
   `skills/library/spark.tres` — `Targeting.ENEMY`, `targeting_range`
   ~500px, short cooldown, one `DamageEffect` (EMBER, modest). Learn + equip
   it in slot 3 alongside the existing three (or swap ember bolt's slot —
   implementer's call). Zero new effect classes, same assertion as M0-03.

## Invariants to respect

- The highlight never influences resolution — it *reads* `TargetSelection`,
  it never feeds anything back into the cast path.
- `HighlightComponent` owns no state beyond its visual toggle; it never
  decides *whether* it should glow (the preview component decides).
- Signals/queries travel upward: entities don't know about the mouse, the
  player-side preview does.

## Acceptance criteria

- Moving the cursor near a slime glows it; moving the cursor to empty air
  shifts the glow to the hostile nearest the *player* (the fallback target);
  no hostile in preview range → nothing glows.
- Casting spark always hits the currently glowing entity (spot-check the
  snap, fallback, and out-of-range cases).
- The glowing target dying or despawning drops the glow without errors and
  the glow reappears on the next-best candidate on the following frame.
- Unequipping the last ENEMY skill turns the preview off entirely.
- Full GUT suite green.

## Test ideas

- Preview-vs-resolver property check: for a handful of scripted cursor
  positions around two hostiles, assert the highlighted node `==` the node
  `TargetSelection.find_enemy` returns for the same inputs.
- Highlight handoff: cursor near A → A glows; move cursor near B → A off,
  B on (exactly one glowing at all times when candidates exist).
- Kill the glowing target → no invalid-instance errors, glow moves on.
- No ENEMY skill equipped → `TargetPreviewComponent` resolves nothing and
  no `HighlightComponent` is ever switched on.
- `HighlightComponent.set_highlighted` idempotence: double-on then off
  restores the original visual state.

## Out of scope

- Hover tooltips, nameplates, health-bar-on-hover (nice later; different
  slice).
- Highlight styles per relationship (ally glow, neutral glow) — ENEMY
  preview only until ally-targeted player skills exist.
- Controller aim (the aim-point model supports it; the input mapping is a
  future slice).
- Telegraphing *enemy* casts back at the player (boss territory, M4).
