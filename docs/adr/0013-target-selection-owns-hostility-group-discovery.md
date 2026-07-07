# Hostility resolution lives in TargetSelection, not FactionComponent; candidates are discovered via a scene group

`FactionComponent` (ADR-0007) deliberately carries identity only — `Faction.PLAYER` / `ENEMY` / `NEUTRAL` — and always deferred the question "who is hostile to whom" to a future system. That system is `TargetSelection` (`skills/targeting/target_selection.gd`), an all-static, stateless utility. It owns two things `FactionComponent` never will: relationship rules (`is_hostile`, `is_allied`) and candidate selection (`find_enemy`, `find_ally`) for `Skill.Targeting.ENEMY`/`ALLY`.

Keeping relationships off `FactionComponent` preserves the ADR-0007 split: identity is per-character state that belongs on a component; hostility is a rule about *pairs* of factions, which has no per-character state to own. Splitting them means a future faction (a pet, a boss with its own faction) is a new `Faction` value plus a rule update in one place, not a new component or a migration of existing character data.

**Hostility is a static function, not a data table.** With three factions today, a 3×3 matrix resource would be pure ceremony around one rule ("PLAYER and ENEMY are mutually hostile; NEUTRAL fights no one"). `is_hostile`/`is_allied` encode that rule directly. If factions multiply enough that the rule stops being expressible as a simple predicate — asymmetric hostility, per-pair configuration — a data-driven matrix becomes the right call; until then the extra indirection would cost more than it buys.

**Candidates are discovered via the `&"characters"` scene group, not a manual registry.** `FactionComponent._ready()` adds its parent to the group; Godot removes membership automatically on `queue_free`/exit. `TargetSelection` iterates that group and filters. This keeps the "a character is whatever carries a `FactionComponent`" invariant from ADR-0007 literal — no scene-path assumptions, no separate list to keep in sync, and no physics query that would silently start caring about collision layers.

**Resolution happens once, in `AbilityComponent._resolve_activation`, and is the single source of truth for "who would I hit."** Both the cast path and the M0-05 target-highlight preview call `TargetSelection` directly; neither reimplements hostility or nearest-candidate logic. Two independent implementations would disagree at the edges (a snap-radius boundary, a range check) and the highlight would visibly lie about what a cast will actually hit.

## Considered Options

A hostility matrix as a `Resource` (or autoload dictionary) keyed by faction pairs was considered, mirroring how `StatModifier` and `Skill` are data. Rejected for now per above — three factions and one symmetric rule don't justify a data asset; revisit if that stops holding.

Resolving candidates via `get_tree().get_nodes_in_group("enemies")`/`"allies"` — i.e., letting each character self-register into a hostility-specific group instead of a single identity group — was considered. Rejected: it duplicates what `Faction` already encodes and would need re-deriving (leaving one group, joining another) every time a character's faction changes, whereas the current design derives hostility fresh from `Faction` on every call.

## Consequences

- Adding a faction means: add the `Faction` enum entry, update `is_hostile`/`is_allied` if the new relationship isn't already covered by the symmetric rule, and nothing else — no component or registry changes.
- `TargetSelection` reaches the scene tree via `caster.get_tree()` for group lookup, the one exception `AbilityComponent._resolve_activation`'s "stays static and pure" rule allows — it's a read through the resolver's single documented entry point, not scattered `get_node()` calls.
- Known simplification, deferred to a later story: there is no line-of-sight check. A hostile on the other side of a wall is still a valid, selectable target in M0.
