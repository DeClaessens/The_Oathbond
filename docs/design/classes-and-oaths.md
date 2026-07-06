# Classes of the Keepers — workshop document

Status: **workshop, not contract.** Ideas here graduate into `docs/VISION.md`
(direction) or milestone briefs (specs) when their time comes. Vocabulary
still belongs in `CONTEXT.md` once systems exist.

## The world scaffold

- **Abithrea** — the world. The **Keepers** are an order tasked with keeping
  and farming the land; the day-job is the cover, the night-job is fending
  off **the Fallow** — the untended dark, what grows where no one tends
  (decided 2026-07-06). Every Keeper duty exists because of what happens
  where it lapses.
- **The opening catastrophe** (decided 2026-07-06): a great Keeper — the
  **First Oathbreaker** — broke their vow without rite or mirror; no
  ceremony, no Scar, just betrayal, and the Fallow poured through them.
  The player rebuilds the Grounds and takes the fight outward, ending (for
  1.0) at the First Oathbreaker as pinnacle boss. The villain is the dark
  image of the player's own ascendancy system — every Scar the player
  takes walks the same edge, deliberately. The fight is a thesis
  statement: the difference between breaking an oath and being broken by
  one. It also gives the Oathkeeper/Outcast economies their historical
  cause.
- **Rebuilding the Grounds** is a meta-progression hook worth designing on
  its own later: the order's home as a hub that physically rebuilds as you
  progress — the Skillwright's workshop restored, shrine wardens returning,
  vendors reopening. Professions live here naturally (the day job *is*
  gathering/crafting).

## The class framework

Every class is a **duty of the order** — a day-task whose true purpose is a
night-task. From that duty follow all four fixed elements of a class
(VISION: "class as starting point"):

1. **Base mechanic** — one rule that warps how *shared* loot-skills play in
   this class's hands. Since skills/fragments are common loot, the base
   mechanic is what makes the same spliced skill feel different per class.
2. **The Class Oath** — the vow of the duty. A static build constraint
   (never behavioral) with a keystone payoff.
3. **Vowkeeper path** — keep the oath, deepen it: exclusive talent tree,
   no drawback, bound by the constraint forever.
4. **Two Scars** — each a specific, authored *betrayal of the duty*: a
   ceremonial deed in the world, a mirror-inverted permanent drawback, an
   exclusive tree and signature effect.

Authoring rule of thumb: the Vowkeeper tree is the duty *perfected*; each
Scar tree is the duty *inverted along one axis*. If a Scar's tree could
belong to any class, the betrayal isn't specific enough.

---

## The Warden — guardian / retaliation melee

*Day: raises walls, mends fences, tends the boundary stones. Night: stands
at the stones and holds the line.*

- **Base mechanic — Foothold.** Holding ground builds Foothold stacks
  (defense + skill empowerment); moving decays them. The same spliced
  fireball everyone loots hits harder from a planted Warden. Positioning
  *is* the class.
- **Class Oath — Oath of the Unbroken Line.** Constraint: your off-hand
  bears the Warden's shield, always. Payoff: keystone block, and the
  shield's defenses echo into your damage — you strike with the wall.
- **Vowkeeper — the Line Deepens.** Block, retaliation, aegis; punish
  everything that dares touch what you protect.
- **Scar of the Burned Shield** — *deed: cast your order's shield into the
  Night Forge.* Drawback: your off-hand is sealed forever, an empty hand
  where the wall was. Tree: two-handed fury, burning retaliation — the
  wall, weaponized. Signature: damage scales with what you no longer block.
- **Scar of the Open Gate** — *deed: unlight the boundary stones of your
  own grange and let the dark walk in.* Drawback: permanently reduced max
  health (something passed through you, and took part of you with it).
  Tree: dark symbiosis — lifesteal, shadow-step mobility, fighting
  alongside the thing you admitted. The keeper-out becomes the letter-in.

## The Sower — caster / growth, delayed burst, decay

*Day: plants, grafts, harvests. Night: sows the salt-lines and ember-seeds
along the dark's paths, and burns the blight before it spreads.*

- **Base mechanic — Sowing.** Any skill can be *planted* instead of cast:
  buried in the ground, blooming seconds later with amplified effect. A
  class-level modulator on the whole shared skill pool — the Sower plays
  the battlefield a few seconds in the future. (Tech note: a planted skill
  is a delayed continuation — the same machinery as splicing's vector
  model. Cheap once M3 exists.)
- **Class Oath — Oath of the Tended Row.** Constraint: no metal on your
  body — living garb only (cloth/hide armor slots). Payoff: your garb
  grows — keystone regeneration and armor that scales where metal can't.
- **Vowkeeper — the Harvest.** Bigger blooms, multiple simultaneous
  plantings, regeneration shared with the ground you've seeded.
- **Scar of the Salted Earth** — *deed: salt your own order's seed-fields.*
  Drawback: all healing and regeneration on you is permanently reduced —
  nothing grows in salted ground, including you. Tree: instant detonation —
  planted skills bloom *immediately* at amplified power; the patient caster
  becomes the burst caster. The growth is gone; only the harvest remains.
- **Scar of the Blighted Graft** — *deed: graft the blight into your own
  arm instead of burning it.* Drawback: a portion of your max mana is
  permanently reserved — the graft drinks first. Tree: corruption — blooms
  become blight (damage-over-time conversion), and the blight spreads on
  its own. The burner of blight becomes its gardener.

## The Lamplighter — ranged skirmisher / marks and light

*Day: trims wicks, keeps the road-lanterns, carries post between granges.
Night: first onto the dark roads; their light reveals what hides, and what
is revealed can be killed.*

- **Base mechanic — Marks.** The Lamplighter's hits mark enemies; marked
  enemies are the class currency — bonus effects against them, marks
  consumed for bursts. Every spliced skill becomes a mark-applier or a
  mark-spender in their hands.
- **Class Oath — Oath of the Kept Flame.** Constraint: the Keeper's Lantern
  fills your relic slot, permanently. Payoff: its light is a keystone —
  auto-marking aura, true sight, reveal.
- **Vowkeeper — the Long Watch.** Light: wider auras, sanctified ground,
  marks that strengthen every consumer; the road is safe where you walked.
- **Scar of the Snuffed Wick** — *deed: extinguish your own lantern at a
  shrine of the dark, and walk home unlit.* Drawback: the relic slot is
  sealed forever (an empty hook where the lantern hung), and your light
  radius is permanently reduced. Tree: the unlit hunter — stealth,
  first-strike criticals from darkness, killing what you can no longer see
  coming by becoming what comes unseen.
- **Scar of the False Beacon** — *deed: light a beacon to call the dark
  down upon a rival grange.* Drawback: permanently lowered resistances —
  the dark answered, and it knows your name now. Tree: deception — decoys,
  lures, ambush zones; the guide becomes the trap.

## Sketch: the Steward — alchemist / quartermaster

*Day: ledgers, stores, brewing. Night: keeps the line supplied.* Flask and
concoction mechanics; **Oath of the Full Larder** (inventory/flask
constraints for supply payoffs); Scars around selling the stores or
poisoning the rations. Parked: a consumables-centric class is the hardest
to balance and the least served by splicing — revisit when flasks exist.

---

## Build order (decided 2026-07-06)

**Lamplighter first** (M5 gets its Class Oath): the current player kit
(sprint, super jump, fireball) is already a mobile ranged skirmisher, and
Marks are nearly pure `StatModifier` tech on existing systems — the
cheapest base mechanic to build. **Warden second** (M6): maximally
different feel — planted melee vs. mobile ranged — which is exactly what
"class as starting point" must prove; Foothold is also modifier-tech.
Sower third: its Sowing mechanic wants splicing's continuation machinery
mature. Steward: parked.

## Open hooks (decide before M4 world-building)

- **Whether "rebuilding the Grounds" is a formal meta-system** (hub tiers
  gating vendors/professions) or just quest staging. It is also the
  standing thematic anchor for the parked spatial charm board — see the
  open questions in `docs/design/stats-and-gear.md`.
- **Enemy families of the Fallow** — what the untended dark actually
  *is* on screen (overgrowth, the unburied, lapsed things); design with
  the M4 zones.
- **The First Oathbreaker's class and broken oath** — which duty did they
  betray? Picking one of the shipped classes makes the mirror sharpest
  (a Warden who opened the gate at the order's heart is the obvious
  candidate once the Warden exists at M6).
