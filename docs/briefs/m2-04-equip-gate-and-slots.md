# M2-04 — Equip gate & slots

*Depends on M2.2 (attributes exist to require against) and M2.3 (items exist
to equip). The story that makes loot change your stats.*

## Goal

Equip an item into its slot and your stats change; unequip and they change
back exactly; an item you lack the attributes for refuses to equip — in the
UI *and* on load, through one shared legality function. This is the payoff of
M2.2 + M2.3 and the second real appearance of "player-authored state
validated at one gate" (after the save gate). Design source:
`docs/design/stats-and-gear.md` (Gear slots, The equip gate).

## Design decisions (made — do not reopen)

1. **Eleven equip slots over ten item types.** `EquipSlot` enum
   (`items/core/item_types.gd`, alongside `ItemSlot`): `WEAPON, OFF_HAND,
   HELM, BODY, GLOVES, BOOTS, BELT, AMULET, RING_1, RING_2, RELIC` (11).
   A `RING` item type is legal in either `RING_1` or `RING_2`; every other
   item type maps to exactly one equip slot. A static
   `accepts(equip_slot, item_slot) -> bool` is the slot-match rule
   (`RING_1`/`RING_2` both accept `RING`; others require equality).
2. **`EquipmentComponent`** (`components/equipment/equipment_component.gd`,
   `class_name EquipmentComponent extends Node`) on the player, sibling by
   `of()`. Owns `var _equipped := {}` (EquipSlot → ItemInstance or absent).
   API:
   - `equip(item: ItemInstance, slot: EquipSlot) -> EquipResult` — validates
     (decision 3); on success, unequips whatever occupies `slot` back to
     inventory, removes `item` from inventory, records it, and **applies its
     mods** (decision 4). On failure applies nothing and returns the reason.
   - `unequip(slot: EquipSlot) -> void` — removes the item's mods by source,
     returns the item to inventory, clears the slot.
   - `equipped(slot) -> ItemInstance` / `all_equipped() -> Dictionary`.
   - Signal `equipment_changed(slot: EquipSlot)`.
   It finds the sibling `StatsComponent` and `InventoryComponent`.
3. **One gate: `Equipment.validate(item, slot, stats) -> EquipResult`**
   (static, `components/equipment/equipment.gd` or on the component as a
   static func). `EquipResult` (`class_name EquipResult extends RefCounted`):
   `ok: bool`, `reason: StringName`. Rules at M2, checked in order:
   slot match (`accepts`, else `&"wrong_slot"`); attribute requirements —
   every `(attr, required)` in the definition's `attribute_requirement` must
   satisfy `stats.get_stat(attr) >= required`, else `&"requirements_not_met"`.
   Oath/material/sealed-slot rules are **future** (M5) — leave the ordered
   check list open to extension but add none now. This exact function is
   called by the equip UI *and* by load (decision 6); legality is never
   written twice.
4. **Equipping applies affixes as `StatModifier`s sourced by the instance.**
   For each affix in the item's `implicit_mods` + `rolled_affixes`, build a
   `StatModifier` (`stat`, `op`, `value` copied; `source = item` (the
   `ItemInstance`); `duration = 0.0` permanent; no `key` — item mods
   accumulate, they don't stack-merge), and `stats.add_modifier(mod)`. This
   is the `StatBuffEffect` authoring pattern (M0) with the item instance as
   source instead of the effect. Unequip removes them all by source
   (decision 5).
5. **Add `remove_by_source` to `StatsComponent`** (the engine gap):
   `func remove_by_source(source: Object) -> void` erases every `_mod` whose
   `.source == source`, then emits `stat_changed` once per affected stat —
   **routing through the same dependent-emission helper ADR-0016 defines**,
   so removing a `+Might` item also refreshes `max_health`. Equip using
   per-affix `add_modifier` already emits correctly; unequip must use this
   single bulk path, not N individual removes, and must not miss the
   dependent emission (the trap: a plain `_mods.erase` loop that forgets to
   emit leaves the cached pools stale).
6. **Equipment persists and re-validates at the gate on load.** Character
   document gains an `"equipment"` section: `{ "<EquipSlot name>":
   {def_id, rarity, affixes:[...]} }` per occupied slot (same instance shape
   as inventory). On load, for each stored slot: rebuild the `ItemInstance`,
   run `Equipment.validate` against the *current* character (attributes are
   loaded first — decision 7); if legal, equip it (applying mods); **if
   illegal (e.g. the player respec'd below the requirement), route it to
   inventory instead** and `push_warning`. `SaveValidator` sanitizes the
   section structurally (drop unknown def ids / malformed affixes / bad slot
   names with a warning); the *legality* re-check is `EquipmentComponent`'s
   job at apply time, not the structural validator's — two distinct gates
   with distinct jobs, both mandatory.
7. **Load order gains equipment, before the pools:** experience →
   attributes → **equipment** → health → mana → skills → inventory.
   Equipment must apply its max-pool-affecting mods (e.g. `+max_health`
   armor, `+Might`) *before* health/mana clamp their persisted currents, or
   a character saved at 140/150 (150 via armor) reloads clamped to the
   base-only max — the same ADR-0015 clamp hazard attributes already dodge.
   Amend the load-order note in ADR-0015's living consequences / the save
   code's ordering comment.
8. **Equipment panel** (`ui/equipment/equipment_panel.gd` + `.tscn`): the 11
   slots shown as a list or paper-doll, each showing its equipped item (or
   empty); clicking an inventory item equips it to its slot (rings to the
   first free ring slot, else `RING_1`), clicking an equipped item unequips
   it. A refused equip surfaces the `reason` as simple text (no toast
   system). Binds `equipment_changed` + `inventory_changed`. Reuse/extend
   the M2.3 inventory panel toggle (`I`) — equipment and inventory share one
   screen. Functional, not styled.

## Invariants to respect

- **Unequip = remove_by_source, exactly once, through the ADR-0016
  emission** — the correctness spine of the whole story. Verify max pools
  and derived stats return to their pre-equip values to the number.
- ADR-0001: item mods are `StatModifier`s composed with everything else;
  a `+10% max health` item and Might-derived health compose per the formula.
- ADR-0003: equipped items are `ItemInstance`s (save data); equipping never
  mutates a Resource. The applied `StatModifier`s are transient runtime
  state rebuilt from the instance on load — never serialized (ADR-0015).
- ADR-0015: the structural save gate and the equip legality gate are
  separate and both run on load; do not fold legality into `SaveValidator`
  (it has no `StatsComponent` to check requirements against).
- One legality function (decision 3) — UI and load call the same
  `Equipment.validate`; a second copy is a review failure.

## Documentation this brief owes

- **CONTEXT.md**: **Equip Slot** (the 11 body slots; distinct from an
  item's `ItemSlot` type — Ring ×2 over one type), **Equip Gate**
  (`Equipment.validate` — the one legality check for slot match + attribute
  requirements, later oaths; called by UI and load alike), **Equipped Item**
  (an ItemInstance in a slot; its affixes are live StatModifiers sourced by
  the instance, removed on unequip). Cross-link to the Save Gate (sibling
  gate, different job).

## Acceptance criteria

- Equipping an item raises the stats its affixes name (measured via
  `get_stat`); unequipping returns every affected stat — including derived
  ones like max_health from a `+Might` item — to the exact pre-equip value.
- Equipping into an occupied slot swaps: the old item returns to inventory,
  the new one's mods replace it, no mod leaks.
- An item whose `attribute_requirement` exceeds the character's attributes
  refuses to equip with `&"requirements_not_met"` and applies nothing; a
  wrong-slot attempt refuses with `&"wrong_slot"`.
- A ring equips into `RING_1` then a second into `RING_2`; both apply.
- Save with items equipped, reload: the same items are equipped and stats
  match; a character saved at near-full pools with pool-boosting gear
  reloads at the saved current, not clamped down (load-order proof).
- On load, an equipped item the character no longer qualifies for (respec
  below requirement) lands in inventory with a warning, not equipped.
- Full GUT suite green (new `class_name`s ⇒ `--headless --import`; confirm
  new test files appear).

## Test ideas

- Equip/unequip symmetry: snapshot every relevant `get_stat` before equip,
  equip a multi-affix item incl `+Might`, assert the deltas, unequip, assert
  exact restoration (the `remove_by_source` + dependent-emission proof).
- `validate` table: wrong slot, unmet requirement (attr one short), met
  requirement, ring in either ring slot.
- Swap: occupied slot → old item back in inventory, mods swapped cleanly.
- Save round-trip with equipment; the near-full-pool load-order case
  (saved 140/150 with +50 armor → reload 140/150); illegal-on-load →
  inventory + warning.
- `remove_by_source` unit test on a bare `StatsComponent`: add three mods
  from one source + one from another, remove by the first source → only the
  other remains, and `stat_changed` fired for each affected stat incl
  derived dependents.

## Out of scope

- Oath / material / sealed-slot constraints (M5) — leave the check list
  extensible, add none.
- `+attribute` affixes being *authored into pools* is M2.3's pool content;
  here they must merely equip and count toward requirements/derived stats.
- Crit and the offense-stat consumers (M2.5).
- Comparing items / stat-diff tooltips, drag-drop, auto-equip, loadouts.
- Flask slots (reserved).
- Set bonuses, item levels, socketing.
