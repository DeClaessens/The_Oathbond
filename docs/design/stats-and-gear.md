# Stats & gear — workshop document

Status: **workshop → hardening.** Core forks were decided 2026-07-06 (marked
below); numbers are first-guess tuning values, freely changeable. Graduates
into M2 briefs when that milestone starts. Engine substrate this builds on:
`StatsComponent` / `StatModifier` (ADR-0001 composition, ADR-0005 keys).

## What gear is for

Gear answers **"how strong"**; splicing answers "how it plays"; the coupling
between them is **costs** (VISION, splicing decision 4). Gear is also the
canvas oaths and scars draw on: constraints speak in slots and materials
("off-hand sealed", "no metal on your body", "the Lantern fills your relic
slot"), so the slot roster below is design real estate, not inventory UI.

## Decisions (2026-07-06)

1. **Full classic attributes** — with gear requirements.
2. **Damage types: Physical, Ember, Radiance, Rot.**
3. **Crit exists** — chance + multiplier, simple.
4. **Rarity: Common / Quality / Masterwork / Heirloom** (craft-themed).

---

## Attributes

Three attributes, named for the order rather than the genre (working names —
final call at M2):

- **Might** — the arm that holds the line. Warden-flavored.
- **Grace** — the step on the dark road. Lamplighter-flavored.
- **Wit** — the mind that reads the seasons. Sower-flavored.

**Sources.** A fixed number of attribute points per character level
(allocated freely — this is the level-up decision that pairs with the
automatic stat growth from M0-04), a class starting spread (Warden opens
Might-heavy, etc.), `+attribute` gear affixes, and occasional talents.
Because attributes come partly from gear, requirement-chaining ("this ring's
+Might lets me wear that shield") is intended behavior — that's the gearing
puzzle full attributes buy us.

**Two jobs, in priority order:**

1. **Requirements** — the primary job. Gear archetypes gate on attributes:
   heavy armor and shields on Might, precise weapons and light armor on
   Grace, foci/relics and woven garb on Wit. Requirements rise with item
   tier. Builds budget attributes the way they budget mana — and a
   Masterwork you can't wear *yet* is a goal, which is journey fuel.
2. **Modest derived scaling** — the secondary job, kept small so
   requirements stay the point: per point, Might grants +2 max health,
   Grace +0.5% crit multiplier (not chance — chance stays gear/build),
   Wit +1 max mana. Big enough to feel, too small to out-compete real
   affixes — except when a build deliberately stacks one attribute, which
   is the stat-stacking archetype Heirlooms can later exploit ("gain 1%
   Ember damage per 10 Wit").

**Engine consequence (flag for the M2 ADR):** attributes are stats
(`might`/`grace`/`wit` StringNames, modifiable like any other), but derived
scaling makes some stats *depend on another stat*. ADR-0001's composition is
per-stat and independent; the M2 ADR must pick a mechanism (derivation baked
into `get_stat` for a fixed whitelist of pairs, or modifiers recalculated on
`stat_changed`) and must forbid cycles by construction — a fixed one-way
derivation table (attributes → derived stats, never the reverse) is the
simple safe shape.

**Respec:** attribute points are reallocatable for a cost (gold/materials —
cheap early, real later). Full attributes plus *no* respec would make
requirement mistakes character-bricking, which fights the build-tinkering
pillar. Constraints with weight belong to oaths, not to allocation UI.

## Damage types

| Type | Story | Player access | Notes |
|------|-------|---------------|-------|
| **Physical** | steel, stone, the swung arm | everyone | the default |
| **Ember** | hearth, forge, ember-seeds | everyone | current FIRE renames to this |
| **Radiance** | the kept flame; what reveals | Lamplighter-centric, fragments for all | the order's element |
| **Rot** | the Fallow's decay | **gated: Scarred builds and dark fragments** | the enemy's element |

Radiance vs Rot is the thematic axis: Fallow enemies deal Rot (making
`resist_rot` the natural pre-boss chase), and player-side Rot access being
scar/fragment-gated makes wielding the enemy's element *feel* transgressive
— the Blighted Graft Sower and Open Gate Warden are Rot builds by nature.
Four `dmg_<type>` channels, four `resist_<type>` stats, existing engine
machinery (`StatKeys.dmg`/`resist`) unchanged. **Done 2026-07-06:**
`DamageType.FIRE` → `EMBER` renamed (EMBER kept FIRE's enum slot, so
pre-rename assets stay valid — ADR-0005), RADIANCE/ROT appended, and
`fireball.tres` became `ember_bolt.tres` ("Ember Bolt"). The reserved M2
stat keys (crit pair, health_regen, cooldown/mana-cost reduction) exist in
`StatKeys` but nothing reads them until M2.

## Crit

Two stats, no extra systems: `crit_chance` (base 5%) and `crit_multi`
(base 150%). Both roll as affixes; crit-stacking is one recognizable build
direction that trades consistency for spikes. Where crit is *checked*:
outgoing damage calculation (`scale_outgoing` grows a crit roll, or a
wrapper does) — decide placement in the M2 ADR alongside the
damage-pipeline write-up. Floating Combat Text should visibly distinguish
crits from day one (it's the cheapest dopamine in the genre).

## Gear slots

Eleven equipment slots plus a later flask row:

- **Weapon**, **Off-hand** (shield / focus / quiver — the Warden's oath
  slot)
- **Helm**, **Body**, **Gloves**, **Boots**, **Belt** — armor, each carrying
  a **material tag: metal / leather / woven** (the Sower's oath speaks in
  materials; future oaths can too)
- **Amulet**, **Ring ×2** — jewelry, no materials
- **Relic** — the class-item slot: the Lamplighter's Lantern lives here;
  the Snuffed Wick scar seals it. Non-class relics exist as loot for
  classes whose oath doesn't claim the slot.
- *(later)* **Flasks** — their own row, arriving with their own design
  pass; scars/oaths already reference flask slots, so the row is reserved.

**The equip gate.** One shared `validate()` decides whether an item can be
worn: slot match, attribute requirements, oath/scar constraints (sealed
slots, material rules). Same philosophy as splicing's validator — one
function, called by the inventory UI and by save-load alike; legality is
never implemented twice. Gear, splices, and oaths all converge on
"player-authored state validated at one gate" — M1's save design should
treat that as a load-bearing pattern.

## Stat roster at 1.0 (gear-relevant)

- **Attributes:** might, grace, wit
- **Offense:** flat added damage per type (new — weapon identity),
  `dmg_<type>` %-increases (exists), crit_chance, crit_multi
- **Defense:** max_health (exists), health_regen (new), `resist_<type>`
  (exists, 90% cap stands)
- **Coupling (the splice-funding group):** max_mana, mana_regen (exist),
  **cooldown_reduction**, **mana_cost_reduction** (new — scarce and prized;
  these are how gear funds dense spliced skills)
- **Utility:** move_speed, jump_velocity (exist — *keep as affixes*:
  movement gear changes how zones play, very MapleStory, very
  journey-pillar)

Deliberately absent: dodge/avoidance (positioning is the dodge in a
platformer; RNG death-avoidance fights build-execution), attack/cast speed
(the GCD is the tempo knob; cooldown_reduction is the speed stat), block
(parked until the Warden needs it at M6 — it can arrive as class tech, not
a global stat).

## Rarity & affixes

| Tier | Affixes | Role |
|------|---------|------|
| **Common** | 0 | floor loot, salvage fodder for professions |
| **Quality** | 1–2 | the leveling workhorse |
| **Masterwork** | 3–5 | the chase tier; endgame min-max canvas |
| **Heirloom** | authored | hand-made uniques: named, lore-bearing, rule-bending (Keeper relics with stories — "Brannick's Last Lantern"). Where stat-stacking hooks and, someday, fragment-on-gear experiments live. |

Affix pools are **per slot-family** (weapons roll offense; armor rolls
defense/attributes; jewelry rolls widest, including coupling stats), with
**value tiers scaling by zone level** — old zones drop lower tiers of the
same affixes, which zone-mastery modifiers can later bend (M4's problem).
No prefix/suffix split at M2: affix-count caps per rarity are enough until
crafting professions (M4) need finer structure; add the split then if
crafting design demands it, not before.

**Architecture (the ADR-0003 pattern, third appearance):** an item
*definition* (base type: "Sickle", implicit stats, slot, material) is an
authored Resource; a *dropped item* is rolled instance data — definition id
+ rarity + affix list with rolled values — living in character save data,
exactly like spliced skills. Equipping applies `StatModifier`s tagged with
the item instance as source; unequip removes by source. Never a mutated
Resource.

## Open questions (deferred)

- ~~Attribute names final?~~ **Resolved 2026-07-08 (M2.1): Might / Grace / Wit
  locked** — stat keys `might`/`grace`/`wit`. See `docs/briefs/m2-02-attributes.md`.
- The M2 mechanism forks graduated into ADRs at M2.1: derived stats →
  ADR-0016 (one-way table), crit placement → ADR-0017 (outgoing packet).
- All numbers (points per level, requirement curves, affix ranges, drop
  weights) — M2 tuning.
- Whether Heirlooms can carry fragment affixes (the VISION open question —
  revisit after M3 proves splicing).
- Salvage/currency economy for professions — design with M4 professions.
- Whether Rot access needs a *softer* early tease (a single low-tier Rot
  fragment pre-Scar?) so the gating reads as "locked", not "nonexistent".
- **Charm board (parked, decided 2026-07-06):** body slots stay; a
  *separate* Bazaar/Last-Epoch-style spatial board is reserved as a
  possible M4+ system. Two hard requirements before it gets designed:
  (1) placement must change outcomes — adjacency/shape rules that
  interact, not affixes-with-extra-clicks (the D2-charm failure mode);
  (2) it needs a real thematic anchor — the rebuilding-the-Grounds hub is
  the standing candidate (a shrine/plot at the order's home you arrange).
  If it can't meet both, the arrangement-pleasure ideas (sized pieces,
  adjacency) go into the splicing grammar instead.
