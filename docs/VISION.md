# Oathbond — Vision & Roadmap

This is the design backbone for Oathbond's future development. It records the
game's pillars, its signature systems, the structural decisions already made,
and a milestone roadmap. Any session (human or agent) planning new work should
start here, then check `CONTEXT.md` for current domain language and `docs/adr/`
for implementation-level decisions.

Status of everything below: **direction, not contract.** Systems get their real
design (and their ADRs) when their milestone starts. When implementation
contradicts this document, update this document.

## Pitch

A 2D side-scrolling ARPG in a MapleStory-esque world where **the build is the
game**. Players compose their own skills from looted parts, swear binding oaths
that trade restrictions for power, and leave legacies that empower their next
character. Leveling through the world is the point, not the tax — the journey
is the destination.

**Setting**: Abithrea. The **Keepers** are an order tasked with keeping and
farming the land — a day-job that covers their true charge: holding back
**the Fallow**, the untended dark that grows where no one tends. The game
opens with a catastrophe: the **First Oathbreaker**, a great Keeper who
broke their vow without rite or Scar, let the Fallow pour through. The
player rebuilds the Grounds and takes the fight to the Fallow, ending (for
1.0) at the First Oathbreaker as the first pinnacle boss — the dark mirror
of the player's own Scar system. Classes are duties of the order; class
oaths are the vows of those duties (see `docs/design/classes-and-oaths.md`
for the class workshop).

## Design pillars

1. **Buildcraft is the core loop.** Every system — gear, talents, skills,
   oaths — must feed the question "what could my build become?" A system that
   doesn't create build decisions doesn't ship.
2. **The journey is the destination.** Leveling zones stay relevant forever.
   Discovery (oath shrines, fragments, recipes, mastery) lives in the world,
   not in menus or lobbies. Endgame sends players back out into the world.
3. **Constraint creates identity.** The most interesting power comes with
   rules attached (Oaths). Restrictions change how you play, not just your
   numbers — but they constrain the *build*, never the hands: builds are
   created outside combat, and no system polices moment-to-moment combat
   behavior.
4. **Breadth is progression.** New characters are the meta-game (Bonds).
   Account-wide progress rewards playing many classes, never power-creeping a
   single main.
5. **Systems-deep, solo-focused.** All design and engineering energy goes into
   mechanical depth. No networking, no economy-balancing for trade.

## Signature systems

### Skill Splicing (centerpiece — build first)

The engine already models a Skill as metadata plus an ordered list of Skill
Effects. Splicing exposes that architecture as the player-facing loot fantasy:

- **Skill Cores** drop as loot: the chassis of a skill — activation style,
  Targeting, base cooldown/mana cost, and a number of fragment sockets.
- **Fragments** drop as loot: one Skill Effect each, in three grammatical
  roles — **vectors** (how the skill reaches the world: projectile, nova,
  dash), **payloads** (what happens on arrival: damage, debuff, knockback),
  and **modulators** (adverbs altering subsequent fragments: repeat, convert
  damage type, delay).
- The player **splices** fragments into cores to author their own skills,
  within constraints (socket count, capacity/weight, cost scaling per
  fragment, tag compatibility between core and fragment).
- **Order matters — splicing is writing, not shopping.** Effects execute in
  sequence, so "apply vulnerability, then damage" is a different skill from
  the reverse. Unlike commutative socket systems (PoE supports, D3 runes),
  a spliced skill is a sentence the player wrote; mastery is learning the
  grammar's idioms. This is the system's moat.
- The **Skillwright profession** deepens it: extract fragments from found
  skills (destroying the core), reroll fragment magnitudes, add sockets.

Why first: highest impact per effort (the hard part — composable effects — is
built), and it immediately makes loot exciting beyond gear.

Splicing design decisions (made 2026-07-06):

1. **Full continuation execution.** A vector fragment mid-sequence re-aims
   everything after it — a projectile *carries the tail of the sequence* and
   executes it at the point of impact, so `Projectile → Damage → Nova →
   Vulnerability` is "shoot; on hit, damage, then explode, marking everyone
   caught". Multi-stage skills emerge from ordering alone. Fan-out is bounded
   by design rules, not optimization: a per-cast entity budget (spawn cap per
   cast chain), the tail continues **once per impact** (payload math still
   runs per target; per-target continuation exists only on specific rare,
   capacity-heavy fragments), no recursion (a spliced skill can never contain
   a skill — sequences terminate by construction), and the global cooldown
   bounds casts per second. Gets its own ADR at M3.
2. **Hard capacity cap at MVP.** Fragments have weight, cores have capacity,
   over-capacity splices are simply invalid — one shared `validate()` used by
   both the splicing UI and save-load. Overload/instability is deliberately
   parked: a possible M5+ "Scarred core" mechanic (Oathbreaker flavor), not
   an MVP system.
3. **Drawback fragments ship in the splicing MVP.** A small starter set
   (2–3) of extra-powerful fragments whose price is a real effect inserted
   into the sequence ("+80% damage, then you take 10% of damage dealt").
   Because the drawback obeys the same grammar, clever ordering mitigates
   it (dash first, *then* take the recoil) — the clearest proof that order
   matters, and the Oath philosophy at loot scale.
4. **Costs are the gear coupling.** Each fragment scales the skill's mana
   cost and/or cooldown, so dense skills are only sustainable if gear funds
   them. Gear answers "how strong", splicing answers "how it plays", and
   cost is the handshake between them. (This also makes the economy a perf
   governor: the screen-filler skill is naturally low-frequency.)

Player-facing anchors: the splicing UI is a **workbench with a firing
range** (test-cast drafts on a Training Dummy before committing); players
**name their spliced skills**; fragment tooltips give precise numbers but
interactions are discovered by casting; fragments drop in the world (zones,
bosses with signature fragments), never from vendors.

Architectural note: a spliced skill is **player-authored save data**, not an
authored `.tres` asset. ADR-0003 (no runtime state on Resources) applies —
splicing produces serialized character data that reconstructs a Skill at load,
never a mutated authored Resource. This makes the save system a hard
prerequisite.

### Oaths & Scars (the buildcraft spine — redesigned 2026-07-06)

The design law governing everything here: **builds are created outside
combat; combat is where you execute them.** No oath carries a behavioral
rule — nothing watches the player's hands, nothing can snap because of a
panic reflex mid-fight. Every constraint in this system is static and
structural (loadout, slots, stats), enforced at the equip/character screen
and built around in advance.

- **The Class Oath** — the titular Oathbond. Every class carries one from
  creation: the vow its order swears, part of class identity. It imposes a
  build constraint and defines the character's central decision.
- **Scars are our ascendancy system.** A Class Oath can be broken in a small
  number of authored ways — each a deliberate, ceremonial deed performed
  out in the world (carry the order's relic to the forbidden forge; swear
  the counter-vow at a rival shrine). Each break-path leaves a distinct
  **named Scar, and that Scar is the subclass**: an exclusive talent tree
  and a signature effect that exist nowhere else, plus a **permanent static
  drawback to build around** ("your flask slots are sealed", "no off-hand,
  ever" — never a rule about how you play moment to moment).
- **Keeping the oath is a path too.** Each class has roughly three
  destinies: the **Vowkeeper** path (deepen the vow — its own exclusive
  tree, no drawback, but bound by the oath's constraint forever) or one of
  ~2 Scars. Nobody stays baseline; loyalty is a build, not an absence.
- **Exactly one Scar per character.** One oath, one decision, one scar (or
  none — Vowkeeper). Clean identity, clean balance surface; the other
  scars are what alts are for, which feeds Bonds.
- **The mirror principle**: each Scar is the thematic inversion of the oath
  it broke — named, handcrafted, collectible in a codex. The drawback is
  the shape of the promise broken.
- **Minor oaths** are collected at shrines found in the world — keystone-
  scale payoffs for static build constraints ("your off-hand stays empty;
  your strikes gain 40%"), unswearable at shrines for a real cost, no
  Scars attached. Horizontal progression that keeps every zone worth
  visiting at any level; stacking several means building around several
  constraints at once.
- **The world reads your choice — two economies.** Oathkeeper NPCs (shrine
  wardens, temple vendors) and Outcast NPCs (the scar-broker, the disgraced
  Skillwright) open different doors, prices, and quests depending on
  whether you're sworn or scarred. Disposition, never combat hostility —
  parallel paths, neither strictly better. The same zones offer different
  content to a Vowkeeper and a Scarred character: horizontal replay value.

Mechanically: minor oaths and scar drawbacks are permanent Modifiers plus
equip-time validation (the stat system already expresses the payoff side);
Scars additionally gate talent trees. Ceremonial break-deeds are world
content, not systems.

### Bonds (the alt engine)

- A character that reaches milestones becomes a **Bondmate** on the account.
- New characters **invoke a bond** with a Bondmate, inheriting an echo of
  their signature — a class-flavored boon, possibly a weakened form of one of
  their spliced skills.
- Every class leaves a *different kind* of legacy, so specific builds want
  specific Bondmates leveled — the mechanical reason to roll every class.
- Strictly bounded power: bonds enrich a new character's start and identity;
  they must never become mandatory grind for the ceiling.

Requires account-level persistence (see Structural decisions) and ≥2 classes
to mean anything — deliberately a later milestone.

## Supporting systems

- **Classes — "class as starting point."** A class fixes your base mechanic,
  talent tree, starting kit, and its **Class Oath** (see Oaths & Scars);
  skills/fragments are mostly shared loot. Distinct early feel and alt
  identity without authoring an exclusive skill pool per class.
- **Gear & itemization.** Gear slots carrying Modifiers (the stat system
  already supports this). Affixes roll on drops; crafting professions
  manipulate them. Gear answers "how strong"; splicing answers "how it
  plays". Core decisions made 2026-07-06 — full classic attributes
  (Might/Grace/Wit, gear requirements), damage types Physical/Ember/
  Radiance/Rot (Rot is the Fallow's element, player-gated behind Scars),
  simple crit, Common/Quality/Masterwork/Heirloom rarities, an 11-slot
  roster with material tags and a relic slot — see
  `docs/design/stats-and-gear.md`.
- **Talents.** Per-class tree of permanent choices; the place where class
  identity deepens over a character's life.
- **Professions.** Gathering happens *while leveling* (journey feeds
  crafting); crafting includes the Skillwright (fragments/cores) and
  gear-focused professions. Recipes are discovered in the world.
- **Zones & the journey.** MapleStory-style vertical maps with strong
  individual identity. Zone mastery tiers keep old zones relevant; oath
  shrines, fragments, and recipes are placed in leveling content so endgame
  players return to the world.
- **Bosses.** Set-piece encounters gating milestones and dropping unique
  cores/fragments. Boss design leans on the symmetric skill system — bosses
  are authored from the same Skill/Effect vocabulary as players (ADR-0002
  spirit).
- **Endgame.** Evergreen, world-based (no seasonal treadmill yet): max-tier
  zone mastery, oath-stacked challenge content, boss gauntlets, deep splicing
  chases, Scar-build experimentation. Design properly at its milestone.

## Structural decisions (made 2026-07-06)

1. **Persistent characters now; seasonal-ready later.** Characters live
   forever in a persistent world. Seasons/leagues are a someday-maybe, so we
   don't build them — but we don't foreclose them either. Concretely:
   **account state and character state are separate from the first save-system
   commit** (bonds/oath-collection/unlocks vs. one character's gear/skills/
   progress), and content stays data-authored so a future "season" is a data
   package, not an engine fork.
2. **Class as starting point** (see Supporting systems).
3. **Skill Splicing is the first signature system built.**
4. **Solo only.** No multiplayer, ever, unless this document is revised. Do
   not pay networking costs "just in case" — no authority abstractions, no
   replication-friendly indirection.

Implementation-level decisions still get ADRs in `docs/adr/` as they're made;
this document holds the vision-level ones.

## Roadmap

Milestones are outcome-oriented and ordered by dependency, not by calendar.
Each milestone should end with the game being *playable and fun at its new
size*, not with a half-wired system.

- **M0 — Combat completeness.** Death handling and respawn; basic enemy AI
  that uses the skill system; a target-selection system so Ally/Enemy
  Targeting resolves (Factions already carry identity — aim model: snap to
  the hostile nearest the cursor, falling back to nearest-to-caster, with
  the would-be target highlighted); a **global cooldown**
  on `AbilityComponent` (bounds cast rate for feel *and* as the perf ceiling
  splicing's fan-out budget multiplies against — decide early which skill
  types, e.g. movement skills, bypass it); XP and character levels. *Exit: a
  play session where you fight, die, and level.*
- **M1 — Persistence.** Save/load with the account/character split from
  decision 1. *Exit: quit and resume a character; account file exists even
  though only bonds will use it later.*
- **M2 — Loot & inventory.** Item drops, inventory UI, gear slots applying
  Modifiers, affix rolls. *Exit: killing things drops gear that changes your
  stats.*
- **M3 — Skill Splicing MVP.** Cores and fragments as loot; splicing UI;
  socket/capacity/cost constraints; spliced skills serialize with the
  character. *Exit: the first skill a player authored themselves gets cast.*
- **M4 — The journey, v1.** First real zone set with identity and vertical
  layout; zone mastery v1; gathering + Skillwright profession v1; first boss.
  *Exit: a 1–2 hour leveling journey that feels like the pitch.*
- **M5 — Oaths & Scars.** Minor-oath shrines in the M4 zones; the
  **Lamplighter's** Class Oath (Oath of the Kept Flame) with its Vowkeeper
  path and at least one Scar (exclusive tree, signature effect, drawback)
  reachable through a ceremonial break-deed in the world. *Exit: two
  characters of the same class that build and play meaningfully differently
  because of what they did with their oath.*
- **M6 — Second class + Bonds.** The **Warden** — planted melee against the
  Lamplighter's mobile ranged, the strongest possible proof of "class as
  starting point"; Bondmate milestones and bond invocation on the account
  layer. *Exit: a reason to roll character #2 that isn't boredom.*
- **M7 — Endgame v1.** Evergreen endgame from the pieces above: mastery
  ceilings, oath-stacked challenges, boss gauntlet. *Exit: die-hards have a
  min-max ceiling worth chasing.*

## Open questions (deliberately deferred)

- Death penalty model — decide in M0. (The 2026-07-06 Scar redesign removed
  the oath/death interaction: no behavioral rules means no death clauses.
  For a build-tinkering game, cheap respawn — as currently built — may
  simply be the answer; ADR-0012's deferral note is superseded by this.)
- Difficulty scaling: fixed zone levels (MapleStory) vs. scaling — decide in
  M4.
- Respec rules for talents and minor oaths (minor oaths should be costly to
  unswear by design; talents maybe not) — and the bigger one: can a Scarred
  character ever atone and re-swear, or change Scars? An endgame-scale
  atonement pilgrimage is the leading idea; PoE precedent says *some* path
  should exist. Decide at M5.
- Whether a Scarred Bondmate leaves a different (darker) echo than a
  Vowkeeper Bondmate — decide with Bonds at M6.
- Art direction and tone beyond "MapleStory-esque" (cute-with-teeth? somber?).
- Class count at 1.0 — the first three (Lamplighter, Warden, Sower) and
  their base mechanics are worked out in `docs/design/classes-and-oaths.md`;
  whether 1.0 ships three, four (the parked Steward), or more is open.
- ~~Whether spliced-skill power and gear power stay orthogonal or feed each
  other~~ — answered 2026-07-06: costs (mana/cooldown scaling per fragment)
  are the coupling point; see Splicing design decision 4. Still open within
  it: whether gear can also carry fragment affixes directly.
- The `SkillContext` blackboard contract: modulators need named channels
  ("next damage becomes fire") with rules, or effect interactions turn into
  spooky action — needs a short design pass before the first modulator is
  built (M3).
- Global cooldown exceptions (do movement skills bypass it?) — decide in M0;
  this defines combat cadence.
