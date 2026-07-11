# M2-06 — Skills Window (loadout & swap)

*New QoL/UX story added mid-M2. No brief dependency; touches the skill/ability
layer (`Skill`, `SkillCatalog`, `AbilityComponent`, `Player`) and adds a new
UI panel. Not part of the M2 loot exit criterion — prompted by the M1 save
system (autosave-on-quit + Save Gate) making skill swaps hard to test without
editing code.*

## Goal

A player-facing **Skills Window**, opened with `S`, that lets you reassign your
four Ability Slots by dragging skills — the project's first interface held to a
real interaction-UX standard (not the "functional, not styled" bar of the
inventory/attributes panels). The top row shows the four Ability Slots; below,
an **Available Skills** panel lists every player-grantable skill; dragging one
onto a slot equips it. Because equipping also *learns* the skill, the change
survives the autosave/Save-Gate round-trip — which is the whole point: swap a
skill, close, test it, and it sticks.

This is a real loadout screen, not a debug overlay: it stays in the shipping
game. Design was locked in a grilling session (2026-07-11). The domain split it
rests on — **Known** vs **Equipped** skills — is in `CONTEXT.md` ("Known Skill /
Equipped Skill"); the read-only counterpart it must not duplicate is the **Skill
Bar** HUD.

## Design decisions (made — do not reopen)

1. **New authored field `player_grantable` on `Skill`.** Add
   `@export var player_grantable: bool = true` to `skills/core/skill.gd` (after
   `ignores_global_cooldown`). It marks a skill as one a *player* can hold, as
   opposed to enemy-only skills. Set `player_grantable = false` in
   `skills/library/slime_bite.tres` (the only enemy skill today). Leave every
   other library `.tres` untouched — they inherit the `true` default, so a v1
   asset with no line loads as grantable. Rationale: the Skill Catalog
   deliberately mixes player and enemy skills (`CONTEXT.md` "Skill Catalog"), so
   the window needs an authored, future-proof marker rather than a hard-coded
   denylist.

2. **`SkillCatalog.grantable_skills()` is the single source for the library.**
   Add to `skills/core/skill_catalog.gd`:
   ```gdscript
   static func grantable_skills() -> Array[Skill]:
       var catalog: SkillCatalog = load(CATALOG_PATH)
       var result: Array[Skill] = []
       if catalog == null:
           return result
       for skill in catalog.skills:
           if skill != null and skill.player_grantable:
               result.append(skill)
       return result
   ```
   Order = authored catalog order (deterministic). `load()` is resource-cached,
   so no manual caching. The UI never touches the `.tres` directly — it asks the
   catalog, exactly like `by_id`. Today this returns 5 skills
   (`sprint`, `super_jump`, `spark`, `smite`, `ember_bolt`) — `slime_bite`
   excluded.

3. **Equipping from the window also learns (`grant_and_equip` on `Player`).**
   Add to `entities/player/player.gd`:
   ```gdscript
   func grant_and_equip(skill: Skill, index: int) -> void:
       learn_skill(skill)
       abilities.equip(skill, index)
   ```
   This is where the learn-then-equip rule lives (one named, testable place),
   above `AbilityComponent` because knowing skills is a Player concern, not the
   symmetric component's (ADR-0002). The window calls this for library→slot
   drops. **Non-negotiable rationale:** the Save Gate turns any equipped id
   missing from `known` into an empty slot (`CONTEXT.md` "Save Gate"), so
   equipping without learning would be silently wiped on the next load — the
   exact failure this window exists to avoid.

4. **Window = `SkillsWindow` (`ui/skills_window/skills_window.gd` + `.tscn`),
   `class_name SkillsWindow extends CanvasLayer`.** Mirrors the existing panel
   idiom (bind-then-react; `is_open()`), but is interactive, not read-only.
   Structure:
   - Root `CanvasLayer`, `process_mode = PROCESS_MODE_ALWAYS` (must run while the
	 tree is paused — see decision 8).
   - A full-rect backdrop `Control` (dim panel) with `mouse_filter = STOP`, so
	 clicks land on the window, never on the game (a click in the game casts at
	 the mouse; the backdrop prevents accidental casts while dragging).
   - A centered `Panel` window: a header label "Skills"; a top row of four
	 **equip-slot** views; below, an "Available Skills" label and a
	 `GridContainer`/`HFlowContainer` of **library-entry** views.
   - `func bind(abilities: AbilityComponent, player: Player) -> void` stores both,
	 connects `abilities.slot_changed` to refresh the top row, builds the library
	 once from `SkillCatalog.grantable_skills()`, and refreshes the slots.
	 `func is_open() -> bool` returns visibility.

5. **Equip-slot views reuse `SkillSlot` for rendering.** Each of the four top
   views embeds the existing `ui/skill_bar/skill_slot.tscn` (or its script) to
   render the equipped skill (icon, or `SkillSlot.first_letter` tile fallback,
   plus the `1`–`4` keybind label) — so the window and the HUD look identical and
   stay DRY. The view adds, on top of that child: the drag/drop handlers
   (decision 6) and a small **✕ button shown only on hover** that calls
   `abilities.unequip(index)`. Do not fork `SkillSlot`'s styling — reuse it.

6. **Drag-and-drop via Godot's Control overrides**, with this exact data
   contract. Drag sources set drag data as a `Dictionary`:
   - a library entry → `{ "kind": "library", "skill": <Skill> }`
   - an equip slot `j` → `{ "kind": "slot", "index": j }` (only when slot `j` is
	 filled)

   An equip-slot view at index `i` implements:
   - `_can_drop_data(pos, data)` → `true` iff `data` is a `Dictionary` whose
	 `"kind"` is `"library"` or `"slot"`.
   - `_drop_data(pos, data)`:
	 - `"library"` → `player.grant_and_equip(data.skill, i)` (**overwrites** slot
	   `i` if occupied).
	 - `"slot"` with `data.index == i` → no-op.
	 - `"slot"` with `j != i` → **swap** slots `i` and `j`: read both skills
	   (either may be null), then `equip`/`unequip` each side to its new content
	   (`unequip` when the counterpart was null). Swap never learns — both skills
	   are already known/equipped.
   - `_get_drag_data(pos)` → the `"slot"` dict (and a drag preview, below) when
	 the slot is filled; `null` when empty.

   Library entries implement `_get_drag_data` → the `"library"` dict plus a drag
   preview. **Duplicates are allowed** — the same skill in two slots is valid
   (`AbilityComponent` tracks cooldown per slot; `CONTEXT.md` "Ability Slot") — so
   no dedup anywhere.

7. **UX-standard affordances (the bar this story raises).** A **drag preview**
   Control (icon/letter tile) follows the cursor via `set_drag_preview`. Valid
   drop targets highlight while a drag is in progress (e.g. modulate/border on
   `_can_drop_data`). Slots and library entries show a **hover** state. Each
   filled slot and each library entry sets `tooltip_text` to a formatted
   multiline string — `display_name`, `description`, `Cooldown: Xs`,
   `Mana: Y` (all read off the `Skill` resource; omit the mana line when
   `mana_cost == 0`). Use Godot's built-in tooltip — no bespoke tooltip node.

8. **Opening pauses the game; closing resumes.** On open: `visible = true`,
   `get_tree().paused = true`. On close: `visible = false`,
   `get_tree().paused = false`. This is a *deliberate divergence* from the
   inventory/attributes panels (which don't pause) — dragging is calmer paused,
   and closing drops you straight into play to test the new loadout. Known,
   accepted limitation: closing the window always unpauses, even if another panel
   is open; there is no pause-menu/stack system yet, so this is fine for now
   (note it in code).

9. **Input: new `toggle_skills` action bound to `S`, plus Esc-to-close.** Add
   `toggle_skills` to `project.godot` `[input]` (physical keycode `83`). `S` is
   currently unbound (movement is `A`/`D`), so no conflict. In `_unhandled_input`:
   `toggle_skills` toggles open/closed; `ui_cancel` (Esc) closes when open. The
   window is `PROCESS_MODE_ALWAYS`, so input still reaches it while paused.

10. **Wiring in `main.gd`.** Add a `SkillsWindow` node to `main.tscn`, cache it in
	`main.gd`, and call `skills_window.bind(player.abilities, player)` in
	`_ready()` alongside the other panel binds. Equipping in the window updates
	the bottom Skill Bar HUD live for free — both bind to the same
	`AbilityComponent` and react to `slot_changed`; no extra wiring.

## Invariants to respect

- **Save Gate (ADR-0015 / `CONTEXT.md`):** equipped ids must be a subset of
  known ids, or the gate empties the slot on load. Decision 3's learn-then-equip
  is the guard — do not add an equip path that skips it.
- **Known vs Equipped are separate (`CONTEXT.md`):** the window promotes an
  Available (grantable) skill to Equipped by learning *and* equipping; it does
  not collapse the two concepts. Unequip (`✕`) leaves the skill Known.
- **`AbilityComponent` is symmetric (ADR-0002):** it stays player-agnostic — the
  learn rule lives on `Player`, never in the component. Use only the existing
  `equip(skill, index)` / `unequip(index)` API; add no window-specific methods to
  it. A swap is two `equip`/`unequip` calls.
- **ADR-0003 (no runtime state on Resources):** `player_grantable` is authored,
  immutable metadata like every other `Skill` field — never written at runtime.
- **Skill Bar stays read-only (`CONTEXT.md`):** do not add editing to
  `ui/skill_bar/`; all mutation lives in the new window.
- **Skill Catalog completeness:** `slime_bite` (and all skills) stay listed in
  `skill_catalog.tres`; `player_grantable` filters the *view*, it does not remove
  a skill from the catalog.

## Documentation this brief owes

- **CONTEXT.md** — two entries:
  - **Grantable Skill**: a Skill with `player_grantable == true` — one a player
    can learn and equip, surfaced in player-facing lists like the Skills Window.
    Enemy-only skills (e.g. Bite) set it `false`. The Skill Catalog still lists
    every skill regardless; `player_grantable` filters the view via
    `SkillCatalog.grantable_skills()`. _Avoid_: "unlocked skill" (there is no
    unlock economy yet).
  - **Skills Window**: the player-facing loadout screen (`ui/skills_window/`,
    toggled by `S`) that reassigns the four Ability Slots by dragging grantable
    skills onto them; equipping learns the skill so it persists through the Save
    Gate. Pauses the game while open. Distinct from the read-only **Skill Bar**
    HUD, which only mirrors the slots. _Avoid_: "skill menu", "inventory" (that is
    items).
- **No new ADR.** `player_grantable` is an additive, optional export with no
  cross-system contract; the pause behavior and learn-on-equip are UI-local
  decisions captured here. If a later story generalizes "player can have this
  skill" (e.g. an unlock/learn economy in M3+), promote it to an ADR then.

## Acceptance criteria

- Pressing `S` opens the window; the game pauses; pressing `S` again or `Esc`
  closes it and the game resumes.
- The top row shows four Ability Slots reflecting the current equip state; the
  "Available Skills" panel lists exactly the five grantable skills (`sprint`,
  `super_jump`, `spark`, `smite`, `ember_bolt`) in catalog order — `slime_bite`
  is **absent**.
- Dragging a library skill onto a slot equips it there: the slot shows it, the
  bottom Skill Bar HUD updates the same slot live, and the skill is now in
  `player.known_skills`.
- Dragging onto an occupied slot **overwrites** it. Dragging one filled slot onto
  another **swaps** the two. The same skill may occupy two slots at once.
- Hovering a filled slot reveals a **✕** that unequips it (slot empties; the
  skill stays known). A skill dragged to a slot then unequipped is still
  listed/available.
- Hovering a filled slot or a library entry shows a tooltip with the skill's
  name, description, cooldown, and (when non-zero) mana cost. A drag shows a
  preview that follows the cursor, and valid drop targets highlight.
- **Persistence:** equip a different skill via the window, trigger a save
  (quit / `SaveManager.save_character`), reload the character — the changed
  loadout is intact (not emptied by the Save Gate), because equipping learned it.
- Full GUT suite green (new `class_name` scripts ⇒ run `--headless --import`
  once and confirm the new test files actually appear in the run).

## Test ideas

Sketches — favor the pure/component-level logic; drag-and-drop wiring itself is
verified manually (see below), not unit-tested.

- **`Skill.player_grantable` default**: a freshly `Skill.new()` is `true`;
  loading `slime_bite.tres` is `false`.
- **`SkillCatalog.grantable_skills()`**: returns the five grantable skills in
  catalog order; excludes `slime_bite`; every returned skill has
  `player_grantable == true`. (Mirror `test/core/test_skill_catalog.gd`.)
- **`Player.grant_and_equip`**: after `grant_and_equip(spark, 2)`, `spark` is in
  `known_skills` and `abilities.slots[2].skill == spark`; calling it for a skill
  already known does not duplicate the `known_skills` entry; the same skill
  equipped at two indices is allowed and both slots hold it.
- **Save round-trip**: on a player, `grant_and_equip` a skill not in the authored
  default kit, `serialize_character` → `apply_character` on a rebuilt player →
  that slot still holds the skill (the learned id kept it past the Save Gate).
  Extends `test/save/` patterns.
- **UI smoke (manual / `godot-headless` + `verify`)**: open with `S`, confirm the
  library count and `slime_bite` absence, drag to equip, overwrite, swap, ✕ to
  unequip, Esc to close, and that the HUD mirrors changes and the game pauses.

## Out of scope (binding)

- Any unlock/availability economy — all grantable skills are shown; "there is no
  real concept of availability right now."
- Skill Splicing / the splicing workbench (Epic M3).
- A shared `Theme` resource or bespoke art direction — this raises the
  *interaction* bar, not the visual-design bar; reuse existing `SkillSlot`
  styling. Art direction stays open (VISION.md).
- Custom themed tooltip nodes (use built-in `tooltip_text`), library search /
  filter / sort, persisting window size or position, right-click context menus.
- Gamepad/controller drag support; touch input.
- Editing the read-only Skill Bar HUD, or rebinding the `1`–`4` skill keys.
- Multi-character loadouts (M1 has one character).
- A pause-menu / panel-stack system (the accepted unpause-on-close limitation in
  decision 8 stands until such a system exists).
