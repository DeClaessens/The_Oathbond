# M0-02 — Target selection: resolving Enemy/Ally Targeting

## Goal

`Skill.Targeting.ENEMY` and `ALLY` currently fail loudly because nothing can
answer "who is an enemy of this caster?" (`FactionComponent` is identity-only
by design). Build the target-selection system so those Targeting modes
resolve, unblocking enemy AI (M0-03) and any targeted skill.

## Design decisions (made — do not reopen)

1. **Relationships live in a new stateless utility, not on
   `FactionComponent`.** Create `skills/targeting/target_selection.gd`,
   `class_name TargetSelection`, all-static:
   - `is_hostile(a: FactionComponent.Faction, b: FactionComponent.Faction) -> bool`
     — PLAYER↔ENEMY are mutually hostile; NEUTRAL is hostile to no one and
     no one is hostile to NEUTRAL.
   - `is_allied(a, b) -> bool` — same faction.
   - `find_enemy(caster: Node, caster_position: Vector2, aim_point: Vector2,
     max_range: float) -> Node` — **snap-to-cursor with fallback** (decided
     2026-07-06): the living hostile nearest `aim_point` within
     `SNAP_RADIUS` of it (and within `max_range` of the caster); if none
     near the aim point, fall back to the living hostile nearest the
     *caster* within `max_range`; `null` only when no living hostile is in
     range at all.
   - `const SNAP_RADIUS := 100.0` on `TargetSelection` — one global value;
     per-skill snap radii only if a design need appears.
   - `find_ally(caster: Node, caster_position: Vector2, aim_point: Vector2,
     max_range: float) -> Node` — same snap-then-fallback rule over allied
     characters, **including the caster** (so ALLY never fails for a solo
     player; it degenerates to SELF until ally NPCs or summons exist —
     intended).
   `FactionComponent` keeps its "identity only" comment but the sentence
   pointing to a "future system" updates to point here.
   **This resolver is the single source of truth for "who would I hit":**
   the cast (here) and the target highlight preview (M0-05) must both call
   it — two code paths for hover vs. cast will disagree at the edges and
   make the highlight lie.
2. **Candidate discovery via a scene group.** `FactionComponent` adds its
   parent to group `&"characters"` in `_ready` (and Godot removes group
   membership automatically on exit). `TargetSelection` iterates that group.
   No physics queries, no scene-path assumptions — a character *is* whatever
   carries a `FactionComponent`.
3. **Dead characters are not targets.** Exclude candidates whose
   `HealthComponent.is_dead()` is true. A character *without* a
   `HealthComponent` remains targetable (health is opt-in, ADR-0007).
4. **Skills carry a range.** `Skill` gains
   `@export var targeting_range := 600.0` (pixels; `0` = unlimited). Only
   read for ENEMY/ALLY targeting.
5. **Resolution happens in `AbilityComponent._resolve_activation`** — the
   caller resolves targets, per CONTEXT.md's Targeting definition. The
   existing `aim_point` parameter is the intent carrier for every Targeting
   mode: the player passes the mouse position (already does, for AREA), and
   the enemy AI passes its chosen target's position — its "cursor". No
   player special-casing in the resolver. ENEMY: `find_enemy(...)` →
   `targets = [it]` and `aim_direction` set toward it (so mixed
   vector/payload skills aim correctly); `null` → fail `&"no_target"` (no
   mana spent, no cooldowns started — the existing flow order already
   guarantees this; keep it that way). ALLY: same with `find_ally`. The
   `push_error` branches for ENEMY/ALLY are removed.
   Note `_resolve_activation` is static and pure — pass the resolved target
   in, or pass `caster` and keep the group lookup inside `TargetSelection`;
   do not let the static function grow scene-tree access beyond that call.
6. **Single target only.** Multi-target selection (chains, smart
   priorities, line of sight) is future splicing/fragment territory.

## Documentation this brief owes

- **ADR-0013**: identity on `FactionComponent`, relationships in
  `TargetSelection`, group-based discovery — and why hostility is code (a
  static function) rather than data (a matrix) until factions multiply.
- **CONTEXT.md**: Targeting's Ally/Enemy bullets change from "not yet
  resolvable" to their real semantics (nearest living hostile/allied
  character within the skill's range; Ally includes the caster). Consider a
  short **Hostility** language entry.

## Invariants to respect

- Effects still read only `SkillContext` — target selection happens *before*
  effects run, in the activation flow, never inside an effect.
- `FactionComponent.of()` stays the resolution idiom; no raw node paths.
- Existing tests in `test_ability_component.gd` assert the ENEMY/ALLY
  `push_error` via `[ExpectedError]` — those tests change meaning. Rewrite
  them to the new contract (resolves / fails `&"no_target"`); do not leave
  expected-error scaffolding pointed at errors that no longer fire.

## Acceptance criteria

- With two hostiles in range, aiming near the *farther* one selects it —
  the snap wins over caster proximity.
- Aiming at empty air (no hostile within `SNAP_RADIUS` of the aim point)
  falls back to the hostile nearest the caster.
- Neutral and same-faction characters are never selected by ENEMY targeting;
  dead characters are never selected by anything.
- No living hostile within `targeting_range` at all → `skill_failed` with
  `&"no_target"`, mana and both cooldowns untouched.
- A hostile near the aim point but *outside* the caster's `targeting_range`
  is not snapped to (range gates the snap, not just the fallback).
- ALLY targeting with no other ally resolves to the caster.
- Full GUT suite green, including the rewritten targeting tests.

## Test ideas

- Hostiles A (near caster) and B (far): aim point on B → B; aim point in
  empty air → A (fallback); aim point on B with B beyond `targeting_range`
  → A.
- Aim point between two hostiles → the one nearer the aim point wins,
  regardless of caster distance.
- Nearest-to-cursor is NEUTRAL, slightly farther one ENEMY → the ENEMY
  one wins (faction filters before distance).
- Snapped candidate is dead (lethal damage first) → next living candidate.
- All hostiles beyond `targeting_range` → `&"no_target"`, assert mana
  unchanged and slot still ready.
- `find_ally` alone in the scene → returns the caster.
- Hostility table unit tests: all 9 faction pairs.

## Out of scope

- Line of sight / platform-aware targeting (a hostile through a wall is
  still a target in M0 — note it in the ADR as a known simplification).
- Target-lock UI, nameplates, hover-targeting.
- Multi-target selection and aggro/threat (M0-03 handles enemy *detection*
  with this same utility; threat tables are not a thing yet).
