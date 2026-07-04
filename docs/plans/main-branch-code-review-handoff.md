# Main Branch Code Review Handoff

Date: 2026-07-04

Scope: first-party Godot/GDScript code on `main`, excluding vendored addons. Review focus was runtime defects, behavioral regressions, data/model risks, and missing tests.

Verification note: static review was completed against source, scenes, authored `.tres` resources, and tests. Local shell commands did not return trustworthy exit statuses in this session, so the GUT suite was not verified from the terminal.

## Findings To Fix

### 1. Exposed `STACK` modifier mode is not implemented

Severity: High

Files:
- `components/stats/stats_component.gd`
- `components/stats/stat_modifier.gd`
- `skills/effects/stat_buff_effect.gd`

`StatModifier.StackMode.STACK` is exported through `StatBuffEffect`, so designers can select it in authored resources. `StatsComponent.add_modifier()` only asserts when it sees `STACK`, with no production implementation for `max_stacks`.

Impact:
- Debug/editor runs can fail as soon as a stacked buff is authored.
- Export/release behavior is likely unsafe because `assert()` is not a runtime invariant; the modifier can fall through and stack without respecting `max_stacks`.

Recommended fix:
- Either remove/hide `STACK` until it is implemented, or implement it fully.
- If implemented, define whether stacks are keyed by `key`, `source`, or both.
- Enforce `max_stacks` and refresh behavior explicitly.
- Add GUT coverage for refresh, stack up to cap, stack over cap, expiration, and signal emission.

### 2. Negative or over-reduced damage can heal targets

Severity: High

Files:
- `components/health/health_component.gd`
- `components/stats/stats_component.gd`
- `skills/effects/damage_effect.gd`
- `skills/effects/spawn_projectile_effect.gd`

`HealthComponent.apply_damage()` subtracts `final_amount` from current health without requiring damage to be non-negative. A negative authored `base_amount`, negative `base_damage`, or outgoing damage modifiers that reduce below `-100%` can produce negative final damage and increase current health up to max.

Impact:
- A malformed damage skill or modifier silently becomes healing.
- `Events.damage_dealt` can emit negative damage numbers, which downstream VFX/UI currently render as combat text.

Recommended fix:
- Clamp damage at the damage boundary, preferably in `HealthComponent.apply_damage()` after mitigation: `final_amount = maxf(0.0, final_amount)`.
- Consider also validating exported damage fields to reject negative authored values.
- Add tests for negative raw damage, outgoing modifiers below `-100%`, and zero damage event behavior.

### 3. Projectile spawn failures consume cooldown and emit success

Severity: Medium

Files:
- `skills/core/ability_component.gd`
- `skills/effects/spawn_projectile_effect.gd`
- `skills/library/fireball.tres`

`SpawnProjectileEffect.execute()` returns early when `projectile_scene` or `ctx.spawn_parent` is null, but `AbilityComponent.activate()` unconditionally sets cooldown and emits `skill_activated` after running effects.

Impact:
- Fireball can appear to cast successfully without spawning a projectile.
- The HUD enters cooldown even though the skill did nothing.

Recommended fix:
- Give effects a success/failure result, or have `AbilityComponent` prevalidate spawn requirements for effects that need scene access.
- Emit `skill_failed(index, &"spawn_failed")` or a more specific reason when a projectile cannot spawn.
- Add tests proving cooldown is not consumed when spawn fails.

### 4. Damage events use `owner` as the target

Severity: Medium

Files:
- `components/health/health_component.gd`
- `vfx/floating_combat_text/combat_text_spawner.gd`
- `test/components/health/test_health_component.gd`
- `test/vfx/floating_combat_text/test_combat_text_spawner.gd`

`HealthComponent.apply_damage()` emits `Events.damage_dealt.emit(source, owner, ...)`. This works for current authored scenes where the component owner resolves to the scene root, but it is fragile for runtime-composed entities, test-built entities, or any future nesting where `owner` is null or not the damaged character node.

Impact:
- Floating combat text can fail to spawn because the event target is null or not a `Node2D`.
- Future runtime-spawned combatants may take damage correctly but emit unusable hit events.

Recommended fix:
- Emit the damaged entity root explicitly, most likely `get_parent()`, after documenting the component placement invariant.
- Add a health-component test that watches `Events.damage_dealt` and asserts the emitted target is the entity node.
- Add a runtime-composed entity test where `owner` is null to prevent regressions.

### 5. Ability slot APIs do not validate indices consistently

Severity: Medium

Files:
- `skills/core/ability_component.gd`
- `ui/skill_bar/skill_bar.gd`
- `test/core/test_ability_component.gd`

`AbilityComponent.equip()` uses `assert()` for index bounds, while `unequip()` and `activate()` index directly into `slots`. Invalid input can crash rather than emitting `skill_failed` or returning safely. `SkillBar` also trusts incoming signal indices.

Impact:
- Any future rebinding, input remapping, save/load data, or AI code that passes an invalid slot can hard-crash.
- Release builds should not rely on `assert()` for runtime validation.

Recommended fix:
- Add a small `_is_valid_slot(index)` helper.
- Make `activate()` emit `skill_failed(index, &"invalid_slot")` for invalid indices.
- Make `equip()` / `unequip()` fail loudly but safely, either by returning a bool or pushing an error and returning.
- Add tests for `-1`, `SLOT_COUNT`, and valid boundary slots.

### 6. Damage effects assume every caster has a `StatsComponent`

Severity: Medium

Files:
- `skills/core/ability_component.gd`
- `skills/effects/damage_effect.gd`
- `skills/effects/spawn_projectile_effect.gd`

`AbilityComponent.activate()` stores `StatsComponent.of(caster)` into the context, but neither activation nor damage-producing effects guard against it being null. `DamageEffect` and `SpawnProjectileEffect` immediately call `ctx.caster_stats.scale_outgoing(...)`.

Impact:
- A mis-composed caster crashes on skill activation.
- This is especially risky because the architecture aims for reusable components across player and enemies.

Recommended fix:
- Decide whether a caster without stats is invalid at activation time or whether damage effects should skip/fail individually.
- Prefer failing activation with a clear `skill_failed(index, &"missing_caster_stats")` when any effect needs caster stats.
- Add tests for a caster without `StatsComponent` using a damage effect and a projectile effect.

### 7. `HealthComponent` can crash before or during `_ready()`

Severity: Medium

Files:
- `components/health/health_component.gd`
- `test/components/health/test_health_component.gd`

`HealthComponent._ready()` resolves `_stats` and immediately calls `_stats.get_stat(...)`. `apply_damage()` also assumes `_stats` has already been assigned by `_ready()`. Since ADR-0009 makes `HealthComponent` load-bearing for damageable entities, composition mistakes and pre-tree damage calls currently become null dereferences.

Impact:
- Any damageable scene missing a correctly named sibling `StatsComponent` fails at runtime.
- Programmatic entities can crash if damaged before entering the tree.
- The failure is not domain-specific, so the next agent/debugger gets a generic null call instead of a useful composition error.

Recommended fix:
- Fail loudly with `push_error()` and disable damage behavior if `_stats` is null, or enforce composition via a reusable validation helper.
- Consider lazy-resolving `_stats` in `apply_damage()` if the component is valid but `_ready()` has not run.
- Add tests for missing stats and pre-`_ready()` damage.

### 8. Health bar visibility does not return to hidden at full health

Severity: Medium

Files:
- `components/health/health_bar.gd`
- `test/components/health/test_health_bar.gd`

`HealthBar._on_health_changed()` only sets `visible = true` when `current < max`; it never hides the bar again when current health returns to max.

Impact:
- A healed entity or future max-health interaction can leave a full health bar on screen indefinitely.

Recommended fix:
- Set `visible = current < max` on every update.
- Add `test/components/health/test_health_bar.gd` for show-on-damage, hide-at-full, and fill fraction behavior.

### 9. Skill and health UI bindings can stack signal connections

Severity: Medium

Files:
- `ui/skill_bar/skill_bar.gd`
- `components/health/health_bar.gd`
- `test/ui/test_skill_bar.gd`

`SkillBar.bind()` and `HealthBar.bind()` connect signals without disconnecting previous bindings or guarding double binds.

Impact:
- Rebinding can duplicate cooldown, ready/fail, and health updates.
- Old ability/health nodes can remain referenced through signal connections.

Recommended fix:
- Track the currently bound node.
- Disconnect old signals before binding a new node.
- Add tests for binding the same object twice and swapping to a different object.

### 10. REFRESH reapply only refreshes duration

Severity: Medium

Files:
- `components/stats/stats_component.gd`
- `test/components/stats/test_stats_component.gd`

When a keyed `REFRESH` modifier is reapplied, `StatsComponent.add_modifier()` resets `remaining` but does not update `value`, `op`, `duration`, or source fields from the new modifier.

Impact:
- A recast after tuning or dynamic scaling keeps the first application magnitude while refreshing time.
- Designer-authored changes can appear ignored during active effects.

Recommended fix:
- Define refresh semantics explicitly.
- If refresh means "replace current application", update all runtime-relevant fields before emitting `stat_changed`.
- Add tests for reapplying a keyed modifier with changed value/op/duration.

### 11. Full scene and physics integration are untested

Severity: Medium

Files:
- `main.tscn`
- `main.gd`
- `entities/player/Player.tscn`
- `entities/enemies/training_dummy/TrainingDummy.tscn`
- `skills/projectile/projectile.tscn`
- `test/`

Current tests instantiate components and call projectile hit handlers directly, but nothing loads `main.tscn`, verifies hard-coded node paths, or proves physics-layer fireball hits reach the training dummy and floating combat text chain.

Impact:
- Broken `$Player` / `$SkillBarHUD` paths, collision-layer regressions, missing `CombatTextSpawner`, or broken `HealthComponent -> Events -> VFX` integration can pass tests.

Recommended fix:
- Add a smoke/integration test that instantiates `main.tscn` and verifies player, HUD, dummy, and combat text nodes are present and bind successfully.
- Add a physics-level projectile collision test, or at minimum scene-contract tests for collision layers/masks.
- Add an end-to-end event test where `HealthComponent.apply_damage()` causes combat text to spawn.

### 12. Health bar still contains debug output

Severity: Low

File:
- `components/health/health_bar.gd`

`HealthBar._on_health_changed()` prints `"health changed"` on every health update.

Impact:
- Combat spam pollutes output and can obscure real errors during test or play sessions.

Recommended fix:
- Remove the print.
- Keep or add tests around `HealthBar.fill_width()` / visibility behavior if changing the class.

## Suggested Implementation Order

1. Fix damage invariants first: clamp/validate non-negative damage and add regression tests.
2. Make failed effect execution observable so projectile spawn failures do not consume cooldown as successful casts.
3. Replace `owner` event target with the damaged entity root and test the global event payload.
4. Make slot index handling and missing component handling explicit.
5. Resolve `STACK` and `REFRESH` semantics either by implementing them or narrowing the authored surface until ready.
6. Fix UI binding/visibility issues, remove debug output, and run the full GUT suite.
7. Add scene/physics integration coverage once the core behavior is stable.

## Test Plan For The Follow-Up Agent

- Run the full GUT suite after each fix batch.
- Add focused tests under:
  - `test/components/stats/test_stats_component.gd` for stack behavior if implemented.
  - `test/components/stats/test_stats_component.gd` for keyed refresh value/op/duration behavior.
  - `test/components/health/test_health_component.gd` for non-negative damage, event target, missing stats, and pre-`_ready()` damage.
  - `test/components/health/test_health_bar.gd` for health bar visibility and fill behavior.
  - `test/core/test_ability_component.gd` for invalid slot handling, missing caster stats, and spawn-failure cooldown behavior.
  - `test/library/test_damage_effect.gd` and `test/library/test_fireball.gd` for negative/over-reduced damage paths.
  - `test/ui/test_skill_bar.gd` for double-bind/rebind behavior and `skill_activated` cooldown start.
- If scene integration changes, add at least one scene-instantiation test for `main.tscn` or the player/dummy scenes.
