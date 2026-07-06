# M0-01 — Global cooldown on AbilityComponent

## Goal

A shared cooldown across all four Ability Slots: after successfully casting a
skill, no other skill can be cast for a short window. This sets combat cadence
("which skill do I press *this* beat"), stops four-key piano-mashing, and is
the perf ceiling Skill Splicing's fan-out budget multiplies against later
(see `docs/VISION.md`, Splicing design decision 1).

## Design decisions (made — do not reopen)

1. **The GCD lives on `AbilityComponent`**, next to the per-slot cooldowns it
   parallels: `@export var global_cooldown := 0.4` and a private
   `_gcd_remaining`, ticked in the existing `_process`. 0.4s is the starting
   value — tune by feel, but keep it well under any real skill cooldown.
2. **Movement skills bypass it — data-driven.** `Skill` gains
   `@export var ignores_global_cooldown := false`. An exempt skill neither
   *respects* the GCD (castable during it) nor *triggers* it (casting it
   starts nothing). One flag, one coherent rule. In a platformer, movement
   must never feel input-gated: set the flag `true` on `sprint.tres` and
   `super_jump.tres`, leave `ember_bolt.tres` respecting it. Edit the `.tres`
   files load-mutate-save or in-editor, never rebuild (ADR-0006).
3. **Check order in activation** (defines which failure reason wins):
   invalid slot → empty slot → global cooldown (unless exempt) → slot
   cooldown → mana → targeting. New failure reason: `&"on_global_cooldown"`,
   emitted through the existing `skill_failed` signal.
4. **The GCD starts only on successful activation**, in the same place the
   slot cooldown is set (after all effects executed). A failed cast never
   costs the player their cadence.
5. **New signal for UI:** `global_cooldown_started(duration: float)` on
   `AbilityComponent`. Skill Bar visualization of it is *out of scope* here —
   the signal just has to exist so the UI can connect later (signals travel
   upward; the component never reaches into UI).

## Invariants to respect

- `_resolve_activation` is a pure static function today; keep the GCD check
  a plain input to it (pass `gcd_ready: bool` in) rather than making it read
  component state — its testability is the point of its shape.
- Failure reasons are `StringName`s matching the existing style
  (`&"on_cooldown"`, `&"insufficient_mana"`).
- Enemies use the same `AbilityComponent` (ADR-0002 spirit) — the GCD applies
  to them automatically. That is desired; do not special-case.

## Acceptance criteria

- Casting ember bolt then immediately pressing another damage skill fails with
  `&"on_global_cooldown"`; after 0.4s it succeeds.
- Sprint/super-jump cast fine during the GCD and do not start one.
- A cast that fails (no mana, on cooldown) does not start the GCD.
- `global_cooldown_started` fires exactly once per successful non-exempt cast.
- Full GUT suite green.

## Test ideas

- Two immediate `activate()` calls on different slots → second fails with
  `&"on_global_cooldown"`; after simulating `_process(0.5)`, it succeeds.
- Exempt skill during GCD → `skill_activated`, and `_gcd_remaining` unchanged.
- Failed cast (empty slot / insufficient mana) → no GCD started.
- Check-order test: slot on cooldown *and* GCD active → which reason? (Per
  decision 3: GCD is checked first, so `&"on_global_cooldown"`.)

## Out of scope

- Skill Bar GCD visualization (dim/sweep) — separate slice, needs the signal
  only.
- Cast times / animation locks — no such system exists yet.
- Per-skill GCD durations — one global value until a design need appears.
