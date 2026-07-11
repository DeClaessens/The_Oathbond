# Dispatch prompt — M2.6 Skills Window

Preconditions: Epic M1 merged (save system + Save Gate exist) and the current
skill/ability layer is intact (`Skill`, `SkillCatalog`, `AbilityComponent`,
`Player`, `ui/skill_bar/`). No sibling story must merge first. Verify
`docs/briefs/m2-06-skills-window.md` exists; stop if not.
Copy everything below the line into a fresh coding session at the repo root.

---

Implement story **M2.6 — Skills Window (loadout & swap)** from the Oathbond
development plan.

Read first, in this order:

1. `docs/handoff/agent-onboarding.md` — the working agreement (definition of
   done, test workflow, git conventions).
2. `docs/briefs/m2-06-skills-window.md` — the spec. Every decision is final; if
   reality contradicts it, stop and report instead of improvising.
3. `CONTEXT.md` — the entries "Known Skill / Equipped Skill", "Ability Slot",
   "Skill Bar", "Skill Catalog", and "Save Gate": the domain this rests on.
4. The `oathbond-skill-system` skill, then the code you extend:
   `skills/core/skill.gd`, `skills/core/skill_catalog.gd`,
   `skills/core/ability_component.gd`, `entities/player/player.gd`, the existing
   panels `ui/skill_bar/` and `ui/inventory/inventory_panel.gd` (the bind-then-
   react idiom to copy), and `main.gd` / `main.tscn` for wiring.

The task: a player-facing **Skills Window** opened with `S`. Four Ability Slots
across the top (reusing the `SkillSlot` renderer), an "Available Skills" panel
below listing every player-grantable skill, and drag-and-drop to assign: drag a
library skill onto a slot to equip it (overwriting), drag one filled slot onto
another to swap, hover-✕ to unequip. Opening pauses the game; `S` again or `Esc`
closes and resumes. It reuses the existing `equip`/`unequip` API and binds to the
same `AbilityComponent` as the HUD, so the bottom Skill Bar updates live.

Three invariants most likely to bite:

- **Equip must learn, or the Save Gate wipes it.** Library→slot goes through
  `Player.grant_and_equip` (learn *then* equip). The Save Gate turns any equipped
  id not in `known` into an empty slot on load — skipping the learn silently
  loses the loadout on the next save/load, defeating the whole feature.
- **`AbilityComponent` stays symmetric (ADR-0002).** The learn rule lives on
  `Player`; add nothing player-specific to the component. Use only its existing
  `equip(skill, index)` / `unequip(index)`; a swap is just those calls.
- **Filter the view, not the catalog.** `slime_bite` stays in
  `skill_catalog.tres`; `player_grantable = false` only hides it from the window
  via `SkillCatalog.grantable_skills()`. Duplicates (same skill in two slots) are
  allowed — do not dedup.

New `class_name SkillsWindow` (and any new `Skill` field / catalog helper) ⇒ run
`--headless --import` once and confirm your new test files appear in GUT's
output before trusting a green run.

Done means: the brief's acceptance criteria hold and are test-backed where the
brief calls for it (`player_grantable` default, `grantable_skills()` filtering
and order, `grant_and_equip` learn+equip + duplicates, save round-trip keeping a
window-equipped skill past the Save Gate), the two CONTEXT.md entries the brief
owes ("Grantable Skill", "Skills Window") are written, the drag/overwrite/swap/
✕/pause/Esc behavior is verified in the running app (`godot-headless` + the
`verify` skill), the full suite is green with new tests verifiably running, and
the work is committed on `feat/m2-06-skills-window`. The out-of-scope list
(unlock economy, splicing UI, shared theme/art, custom tooltip nodes, library
search, gamepad/touch, editing the HUD, multi-character, pause-menu system) is
binding.
