# M2-03 — Item drops & inventory

*Depends on M2.1. Independent of M2.2 — can run in parallel.*

## Goal

Killing things drops gear with rolled affixes; the drop lands in an
inventory you can open and read. This is the loot half of "killing things
drops gear that changes your stats" — the *changing stats* half is equipping
(M2.4); this story builds the item, the roll, and where it lives. Design
source: `docs/design/stats-and-gear.md` (Rarity & affixes, Architecture).

## Design decisions (made — do not reopen)

1. **Definition vs instance (the ADR-0003 pattern, third appearance —
   mirror the M1 skill/save split).**
   - **`ItemDefinition`** (`items/core/item_definition.gd`,
     `class_name ItemDefinition extends Resource`): authored `.tres`.
     `@export`: `id: StringName` (stable save key, like `Skill.id`),
     `display_name: String`, `icon: Texture2D`, `slot: ItemSlot` (enum,
     decision 4), `material: Material` (enum: NONE/METAL/LEATHER/WOVEN —
     jewelry/weapon/relic use NONE), `implicit_mods: Array[ItemAffix]`
     (fixed mods every instance carries — a Sickle's base damage),
     `affix_pool: AffixPool`, `attribute_requirement: Dictionary`
     (`{&"might": 10}` etc., read by M2.4's gate — authored now, unused
     until then).
   - **`ItemInstance`** (`items/core/item_instance.gd`,
     `class_name ItemInstance extends RefCounted` — **not** a Resource;
     runtime/save data only, ADR-0003): `definition_id: StringName`,
     `rarity: Rarity`, `rolled_affixes: Array[ItemAffix]`. Resolves its
     definition through the catalog (decision 6). Never mutates a Resource.
   - **`ItemAffix`** (`items/core/item_affix.gd`, `class_name ItemAffix
     extends RefCounted`): `stat: StringName`, `op: StatModifier.Op`,
     `value: float`. The rolled instance data; on equip (M2.4) each becomes
     a `StatModifier`. (Implicit mods reuse the same type, authored on the
     definition.)
2. **Rarity** (`Rarity` enum on a shared `items/core/item_types.gd`, or on
   `ItemInstance` — one home, cited everywhere): `COMMON=0, QUALITY=1,
   MASTERWORK=2, HEIRLOOM=3`. Affix counts: Common 0, Quality 1–2,
   Masterwork 3–5, Heirloom authored (Heirlooms are hand-made — **out of
   scope to roll here**; the enum value exists, the roller never produces
   one). Roll weights (tunable constants): Common 60 / Quality 30 /
   Masterwork 10.
3. **`AffixPool`** (`items/core/affix_pool.gd`, `class_name AffixPool extends
   Resource`): authored `.tres`, `@export var entries: Array[AffixEntry]`
   where **`AffixEntry`** (`class_name AffixEntry extends Resource`) is
   `{stat: StringName, op: StatModifier.Op, min_value: float, max_value:
   float}`. One pool per slot-family, authored: `affix_pool_weapon.tres`
   (offense — `dmg_<type>`, crit_chance, crit_multi, flat added damage),
   `affix_pool_armor.tres` (defense/attributes — max_health, health_regen,
   `resist_<type>`, might/grace/wit), `affix_pool_jewelry.tres` (widest —
   the coupling stats cooldown_reduction/mana_cost_reduction plus max_mana,
   mana_regen, resists, attributes). Value ranges are first-guess tuning.
   **No prefix/suffix split, no tier-by-zone scaling** (M4) — a single range
   per entry.
4. **`ItemSlot` enum** — the 11-slot roster (`item_types.gd`): `WEAPON=0,
   OFF_HAND=1, HELM=2, BODY=3, GLOVES=4, BOOTS=5, BELT=6, AMULET=7, RING=8,
   RELIC=9`. Ring ×2 is two equip slots over one `RING` item type (M2.4's
   concern); the item type roster is these 10 values (append-only like the
   stat enum — never reorder). Flasks are reserved, not added.
   Slot→family mapping (for pool/validation, a static helper): WEAPON→weapon;
   OFF_HAND/HELM/BODY/GLOVES/BOOTS/BELT→armor; AMULET/RING/RELIC→jewelry.
5. **`ItemRoller`** (`items/core/item_roller.gd`, static
   `roll(definition: ItemDefinition, level: int = 1) -> ItemInstance`):
   picks rarity by weights, picks the affix count for that rarity, draws
   that many *distinct* entries from the definition's `affix_pool` (no
   duplicate stat+op on one item), rolls each value uniformly in
   `[min,max]`. `level` is threaded but unused at M2 (zones are M4) — accept
   and ignore it so the signature is stable. Uses `randf`/`randi`; tested by
   boundaries and invariants (count matches rarity, values in range,
   distinct stats), never by asserting a specific roll.
6. **`ItemCatalog`** — mirror `SkillCatalog` exactly (`items/core/
   item_catalog.gd` + authored `items/item_catalog.tres`), static
   `by_id(id) -> ItemDefinition`, lazy load, `push_error` on duplicate/empty
   ids, one entry per authored definition. A completeness test enforces it
   against `items/` definitions (as the skill test does).
7. **`InventoryComponent`** (`components/inventory/inventory_component.gd`,
   `class_name InventoryComponent extends Node`) on the player: holds
   `var _items: Array[ItemInstance]`, `add(item)`, `remove(item)`,
   `items() -> Array`, capacity `CAPACITY := 40` (tunable; over-capacity
   drops are refused and left in the world). Signal `inventory_changed()`.
   Persists via `save_state()/load_state()` — the character document gains an
   `"inventory"` section: an array of `{def_id, rarity, affixes:[{stat,op,
   value}]}`. Validator rules: each entry whose `def_id` the catalog can't
   resolve is dropped with a warning; malformed affixes dropped; rarity out
   of range clamped. Extend `SaveValidator` and place inventory anywhere
   after skills in the load order (no derived-stat dependency).
8. **Drops come from the victim.** A **`LootComponent`**
   (`components/loot/loot_component.gd`) on droppers, sibling pattern like
   `XpRewardComponent`: `@export var drop_table: Array[ItemDefinition]` and
   `@export var drop_chance: float = 1.0`. On `Events.character_died(victim,
   killer)` where `victim == get_parent()` and `killer` has an
   `InventoryComponent`: with probability `drop_chance`, pick a definition,
   `ItemRoller.roll` it, and **spawn a world pickup** at the victim's
   position (decision 9). The Slime gets a `LootComponent` with one or two
   simple definitions; the Training Dummy gets none.
9. **World pickup → inventory on touch.** A `DroppedItem` scene
   (`items/dropped_item/dropped_item.tscn` + `.gd`, an `Area2D`) carries an
   `ItemInstance`, shows the definition's icon, and on body-entered by a node
   with an `InventoryComponent` calls `add()` and `queue_free`s (if `add`
   refuses at capacity, stay in the world). Collision layer/mask per the
   five-layer scheme (ADR-0008) — pickups detect the player only.
10. **Inventory panel** (`ui/inventory/inventory_panel.gd` + `.tscn`):
    toggled by a new `toggle_inventory` action (bind `I`), lists the player's
    items showing display name, rarity (name/color), and **the rolled affix
    values** (not the definition's ranges — decision-critical: the UI proves
    instances carry their own numbers). Binds `inventory_changed`. Functional,
    not styled; mirror the skill-bar HUD wiring idiom.

## Invariants to respect

- ADR-0003: `ItemInstance`/`ItemAffix` are `RefCounted`, never Resources;
  rolling never writes to an `ItemDefinition` or the catalog. The trap:
  "store the rolled item as a .tres" — forbidden, it is save data.
- ADR-0015 gate + replay: instances persist as plain dicts and every load
  passes the single `SaveValidator`; never serialize live `StatModifier`s
  (there are none yet — equip is M2.4 — but do not pre-build them).
- `ItemSlot`/`Rarity` enums are append-only, order frozen (ADR-0005/0011
  spirit): saved instances store the int.
- ADR-0008 collision layers for the pickup Area2D.
- `ItemCatalog` follows `SkillCatalog` to the letter (lazy static, error on
  dupes) — do not invent a different registry shape.

## Documentation this brief owes

- **CONTEXT.md**: **Item Definition** (authored base type — slot, material,
  implicit mods, affix pool, requirement), **Item Instance** (a rolled drop:
  definition id + rarity + rolled affixes; save data, never a Resource),
  **Affix** (one rolled stat modifier on an instance; becomes a StatModifier
  on equip), **Rarity** (Common/Quality/Masterwork/Heirloom and their affix
  counts), **Item Catalog** (the authored id→ItemDefinition registry, twin
  of the Skill Catalog). Note the definition/instance split cites ADR-0003.

## Acceptance criteria

- Killing the Slime drops a world item with rarity-appropriate affix counts
  (Common 0, Quality 1–2, Masterwork 3–5); walking over it adds it to the
  inventory and removes the world pickup.
- A projectile kill attributes the drop to the projectile's caster (the same
  attribution M0.4 fixed — the killer with the inventory).
- Rolled affix values fall within their pool entry's `[min,max]`; an item's
  affixes are distinct stats; no Heirloom is ever rolled.
- The inventory panel shows each item's rolled values (not the definition's
  ranges), its name, and its rarity.
- Drops persist through save/load: quit with items in inventory, reload,
  the same instances (def id, rarity, each affix value) are present.
- A save with an unknown item def id / malformed affix / out-of-range rarity
  loads sanitized, one warning per repair, no crash.
- Every definition in `items/` appears in `item_catalog.tres`; ids unique
  and non-empty (test-enforced).
- Full GUT suite green (new `class_name`s ⇒ `--headless --import` first;
  confirm new test files appear).

## Test ideas

- Roller invariants over many rolls: affix count ∈ the rarity's range,
  values in `[min,max]`, stats distinct, `Rarity` never HEIRLOOM. Force a
  rarity (inject or loop until each appears) to check counts per tier.
- `LootComponent`: emit `Events.character_died(slime, player)` with the
  player carrying an `InventoryComponent` → a `DroppedItem` spawns; killer
  without inventory → nothing; `drop_chance = 0` → nothing.
- Pickup: body-enter with inventory → `add` called, freed; at capacity →
  stays.
- Inventory round-trip through the save system (mirror M1.2 disk tests) and
  validator table for malformed inventory sections.
- Catalog completeness against `items/`.

## Out of scope

- Equipping / stats actually changing (M2.4) — items only *exist* and are
  *held* here.
- Attribute requirements enforcement (authored on definitions, read by M2.4).
- Heirloom authoring, tier-by-zone value scaling, prefix/suffix (M4).
- Crit and the new offense stats being *read* by the pipeline (M2.5) —
  affix pools may name them, but nothing consumes them until M2.5/M2.4.
- Salvage, currency, vendors, stash (M4).
- Inventory styling, drag-drop, sorting, tooltips — functional list only.
- Loot beauty (rarity beams, drop sounds).
