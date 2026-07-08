# Oathbond — epics & stories (tracker import)

Status: approved breakdown, 2026-07-06. Epics are the `docs/VISION.md`
milestones; stories are vertical slices — each one demoable or verifiable on
its own, never a horizontal layer. Detail tapers on purpose: M0–M3 stories
are grabbable now; M4–M7 epics open with a design pass that splits them when
their milestone nears.

**How to import.** One epic = one Linear project / Jira epic (paste the epic
blurb as its description). One story = one issue (paste the story block as
the body). "Blocked by" maps to Linear's *blocked by* relation / Jira's
*is blocked by* link. Suggested labels, matching `docs/agents/triage-labels.md`:

- `ready-for-agent` — fully specified, a coding agent can start (all M0
  implementation stories: their briefs in `docs/briefs/` are the contract).
- `ready-for-human` — design/decision work (every "design pass" and
  "decision" story).
- `needs-info` — implementation stories whose brief doesn't exist yet
  (M1+ implementation stories; their epic's design pass produces the brief,
  then relabel to `ready-for-agent`).

**Working agreement** (from project memory): planning-tier models and Thomas
write the design passes, ADRs, and briefs; implementation stories go to
Thomas or cheaper coding models. When a brief and reality disagree
mid-implementation, stop and re-plan — never improvise (CLAUDE.md).

---

## Epic M0 — Combat completeness

> Death handling and respawn exist; enemies fight back through the same
> skill system the player uses; targeting resolves with a snap-to-cursor
> aim model and an honest highlight; a global cooldown bounds cast rate;
> XP and levels close the loop. **Exit: a play session where you fight,
> die, and level.** Specs: `docs/briefs/m0-01` … `m0-05`, `m0-08`.

### M0.1 — Global cooldown — ✅ DONE 2026-07-07

**What to build.** A short global cooldown on ability activation: any
successful cast briefly locks all slots, with movement skills (sprint,
super jump) exempt — they neither respect nor trigger it. Failure surfaces
as its own reason so UI can distinguish "GCD" from "slot cooldown". Full
spec: `docs/briefs/m0-01-global-cooldown.md`.

**Acceptance criteria**
- [x] Two damage skills cannot fire within the GCD window; movement skills always can
- [x] GCD starts only on *successful* activation (a failed cast doesn't lock you out)
- [x] A signal announces GCD start so cooldown UI can display it
- [x] Full GUT suite green

**Blocked by:** None — can start immediately. `ready-for-agent`

### M0.2 — Target selection — ✅ DONE 2026-07-07

**What to build.** The missing ENEMY/ALLY targeting resolution: snap to the
hostile nearest the cursor within a snap radius, fall back to the hostile
nearest the caster, fail with `no_target` only when nothing is in range.
The aim point stays the single intent carrier for player and AI alike, and
this resolver becomes the single source of truth that the highlight (M0.5)
previews. Full spec: `docs/briefs/m0-02-target-selection.md`.

**Acceptance criteria**
- [x] ENEMY-targeted casts hit the hostile nearest the cursor when one is in snap range
- [x] With the cursor over empty air, the cast falls back to the hostile nearest the caster
- [x] Nothing in range → cast fails `no_target`, no cost spent
- [x] Dead entities are never targeted; the old "unresolvable targeting" tests are rewritten
- [x] ADR + CONTEXT.md vocabulary updated; full GUT suite green

**Blocked by:** None — can start immediately. `ready-for-agent`

### M0.3 — First real enemy + AI — ✅ DONE 2026-07-07

**What to build.** The first hostile that fights back: a Slime with an
idle/chase/attack controller that detects the player through the same
target-selection utility and attacks by *activating a skill* — zero new
effect classes, proving the skill system serves NPCs as-is. Full spec:
`docs/briefs/m0-03-enemy-ai.md`.

**Acceptance criteria**
- [x] A placed Slime idles until the player is in detection range, chases, and bites in melee range
- [x] Its bite is an authored skill asset going through AbilityComponent (cooldown, GCD and all)
- [x] Player can kill it (existing death/despawn flow) and it can kill the player (existing respawn)
- [x] No new SkillEffect subclasses were needed
- [x] Full GUT suite green

**Blocked by:** M0.2. `ready-for-agent`

### M0.4 — XP & character levels — ✅ DONE 2026-07-07

**What to build.** Kills award XP to the killer; levels grant permanent
stat growth (+max health, +max mana) and a full restore. Overflow XP loops
into the next level; self-kills and unattributed deaths award nothing.
Full spec: `docs/briefs/m0-04-xp-and-levels.md`.

**Acceptance criteria**
- [x] Killing a Slime grants its XP reward to the player; projectile kills attribute correctly
- [x] Leveling applies permanent stat growth and restores both pools
- [x] Overflow XP carries across multiple level-ups in one kill
- [x] ADR-0012 amended for kill attribution; CONTEXT.md gains Experience/Level entries
- [x] Full GUT suite green

**Blocked by:** M0.3. `ready-for-agent`

### M0.5 — Target highlight — ✅ DONE 2026-07-07

**What to build.** The entity a cast would resolve to *right now* glows —
a per-frame preview of the same resolver the cast uses (one code path, so
the highlight can never lie). Contract: whatever glows is what you'll hit,
and something always glows if a cast would succeed. Includes authoring the
player's first ENEMY-targeted skill to point with. Full spec:
`docs/briefs/m0-05-target-highlight.md`.

**Acceptance criteria**
- [x] Cursor near a hostile glows it; empty air shifts the glow to the fallback target; out of range → nothing glows
- [x] Casting always hits the currently glowing entity (snap, fallback, and out-of-range spot-checks)
- [x] Glowing target dying/despawning drops the glow without errors
- [x] No ENEMY skill equipped → preview fully off
- [x] Full GUT suite green

**Blocked by:** M0.2 (best implemented after M0.3). `ready-for-agent`

### M0.6 — Prefactor: rename damage type FIRE → EMBER — ✅ DONE 2026-07-06 (import as closed, or skip)

**What to build.** The damage-type roster decided in
`docs/design/stats-and-gear.md` renames FIRE to EMBER. Do it *now*, while
few `.tres` assets reference it — enum order must not change (ADR-0005),
and every asset authored before the rename is future migration debt.
Rename the enum label, the derived stat names, and revisit `fireball.tres`
(likely becomes an Ember skill in name too).

**Acceptance criteria**
- [x] Enum label renamed with order preserved; existing assets still load and deal the same damage
- [x] Stat keys / display strings say Ember; no FIRE remains outside git history
- [x] Full GUT suite green

**Blocked by:** None — can start immediately. `ready-for-agent`

### M0.7 — Decision: death penalty model

**What to build.** A decision, not code: what dying costs. The Scar
redesign removed oath/death interactions, and for a build-tinkering game
cheap respawn (as currently built) may simply be the answer. Record the
decision in VISION.md's open questions and, if anything changes, a brief.

**Acceptance criteria**
- [ ] Decision recorded in `docs/VISION.md` (open question closed)
- [ ] Follow-up brief filed if the answer isn't "keep cheap respawn"

**Blocked by:** M0.4 (want the fight–die–level loop playable first). `ready-for-human`

### M0.8 — Proving-grounds level + follow camera — ✅ DONE 2026-07-07

**What to build.** Retire the single-slab test floor: a placeholder level
four screens wide with a normal-jump platform route and one
Super-Jump-only ledge, plus the game's first camera — a `Camera2D` in the
player scene, smoothed and clamped to bounds the level exports. Not M4
zone content; this is the sandbox that makes the M0 loop playable at more
than one screen and proves the camera/HUD/world-space seams. Full spec:
`docs/briefs/m0-08-level-and-camera.md`.

**Acceptance criteria**
- [x] Camera follows the player smoothly and clamps at the level bounds — no void ever visible
- [x] Full width traversable; one-way platforms enterable from below; the high ledge needs Super Jump
- [x] Dummy + three spread-out Slimes fight as before; HUD fixed; combat text world-space (regression)
- [x] `Floor.tscn` deleted; level lives under `levels/`; ADR-0014 + CONTEXT.md entries recorded
- [x] Full GUT suite green

**Blocked by:** M0.3 (the Slime exists to place). `ready-for-agent`

---

## Epic M1 — Persistence

> Save/load with the account/character split (VISION structural decision).
> **Exit: quit and resume a character; the account file exists even though
> only Bonds will use it later.**

### M1.1 — Design pass: save architecture — ✅ DONE 2026-07-08

**What to build.** An ADR + implementation brief for persistence. Must
cover: the account/character file split; serialization format and
versioning; and the load-bearing pattern three systems already converge on
— *player-authored state lives in save data and is validated at one gate*
(rolled items, spliced skills, oath constraints — see
`docs/design/stats-and-gear.md` architecture section). The brief leaves the
implementer zero open questions.

**Acceptance criteria**
- [x] ADR covering file split, format, versioning, and the validate-at-one-gate pattern (`docs/adr/0015-save-architecture.md`)
- [x] Brief in `docs/briefs/` labeled `ready-for-agent` (`docs/briefs/m1-02-character-save-load.md`)

**Blocked by:** Epic M0 complete. `ready-for-human`

### M1.2 — Character save/load — ✅ DONE 2026-07-08

**What to build.** Per the M1.1 brief: persist a character (stats, level,
XP, learned + equipped skills) and resume it; create the account file
scaffold alongside.

**Acceptance criteria**
- [x] Quit and resume restores level, XP, pools, and equipped skills exactly
- [x] Account file exists and survives character deletion
- [x] Full GUT suite green

**Blocked by:** M1.1 (done). `ready-for-agent` — brief: `docs/briefs/m1-02-character-save-load.md`

---

## Epic M2 — Loot & inventory

> Item drops, inventory UI, gear slots applying StatModifiers, affix
> rolls — the full design is already decided in
> `docs/design/stats-and-gear.md`. **Exit: killing things drops gear that
> changes your stats.**

### M2.1 — Design pass: M2 ADRs + briefs — ✅ DONE 2026-07-08

**What to build.** Turn `docs/design/stats-and-gear.md` into contracts:
an ADR for the derived-stats mechanism (attributes feeding max health /
crit multi / max mana via a fixed one-way derivation table — cycles
impossible by construction), the crit roll's placement in the damage
pipeline, final attribute names (Might/Grace/Wit are working names), and
briefs for stories M2.2–M2.5.

**Acceptance criteria**
- [x] Derived-stats ADR (`docs/adr/0016`) and crit-placement ADR (`docs/adr/0017`) written
- [x] Attribute names finalized — Might / Grace / Wit (locked 2026-07-08)
- [x] Briefs for M2.2–M2.5 leave zero open questions (`docs/briefs/m2-02`…`m2-05`)

**Blocked by:** Epic M1 complete. `ready-for-human`

### M2.2 — Attributes — `ready-for-agent` · brief `docs/briefs/m2-02-attributes.md`

**What to build.** Might/Grace/Wit as stats: points per level allocated
freely, class starting spreads, modest derived scaling per the design doc,
and respec for a cost. Vertical: level up → allocate a point → watch the
derived stat move.

**Acceptance criteria**
- [ ] Points granted per level and allocatable; derived stats update live
- [ ] Respec returns points for its cost
- [ ] Full GUT suite green

**Blocked by:** M2.1 (done). `ready-for-agent`

### M2.3 — Item drops & inventory — `ready-for-agent` · brief `docs/briefs/m2-03-item-drops-and-inventory.md`

**What to build.** Item *definitions* as authored Resources; *dropped
items* as rolled instance data (definition id + rarity + rolled affixes)
in save data — never a mutated Resource. Kills roll the
Common/Quality/Masterwork tiers with per-slot-family affix pools; pickup
lands in an inventory UI.

**Acceptance criteria**
- [ ] Kills drop items with rarity-appropriate affix counts; drops persist through save/load
- [ ] Inventory UI shows the rolled values, not the definition's
- [ ] Full GUT suite green

**Blocked by:** M2.1 (done). `ready-for-agent`

### M2.4 — Equip gate & slots — `ready-for-agent` · brief `docs/briefs/m2-04-equip-gate-and-slots.md`

**What to build.** The 11-slot roster with material tags and the shared
`validate()` equip gate (slot match, attribute requirements — later, oath
constraints). Equipping applies StatModifiers tagged with the item
instance as source; unequip removes by source. Legality is implemented
exactly once, called by UI and save-load alike.

**Acceptance criteria**
- [ ] Equipping changes stats; unequipping restores them exactly
- [ ] Items you lack the attributes for refuse to equip, in UI *and* on load
- [ ] Full GUT suite green

**Blocked by:** M2.2, M2.3. `ready-for-agent` (brief: `docs/briefs/m2-04-equip-gate-and-slots.md`)

### M2.5 — Crit & the new stat roster — `ready-for-agent` · brief `docs/briefs/m2-05-crit-and-stat-roster.md`

**What to build.** `crit_chance`/`crit_multi` rolled into the damage
pipeline; the new gear stats live end-to-end (flat added damage per type,
health_regen, cooldown_reduction, mana_cost_reduction). Floating combat
text visibly distinguishes crits.

**Acceptance criteria**
- [ ] Crits occur at the expected rate and FCT shows them differently
- [ ] Cooldown/mana-cost reduction measurably change cast cadence and costs
- [ ] Full GUT suite green

**Blocked by:** M2.1 (done). `ready-for-agent`

---

## Epic M3 — Skill Splicing MVP

> The centerpiece. Cores and fragments as loot; a splicing workbench with
> validator; continuation execution with hard budgets; spliced skills
> serialize with the character. Design decisions already made in
> `docs/VISION.md` (Skill Splicing section, decisions of 2026-07-06).
> **Exit: the first skill a player authored themselves gets cast.**

### M3.1 — Design pass: splice contracts

**What to build.** Briefs + ADRs for the splice data model and validator,
the SkillContext blackboard contract (VISION open question — must land
before the first modulator), and the fragment grammar
(vectors/payloads/modulators, drawback fragments included per decision 3).

**Blocked by:** Epic M2 complete. `ready-for-human`

### M3.2 — Cores & fragments as loot

**What to build.** Cores and fragments drop, persist, and appear in
inventory — reusing M2's instance architecture wholesale.

**Blocked by:** M3.1. `needs-info` → `ready-for-agent`

### M3.3 — Continuation execution engine

**What to build.** The runtime: vector fragments carry the remaining
sequence to impact; per-cast entity budget (~16) enforced; tail runs once
per impact; no recursion; GCD bounds cast rate. The perf model is design
rules, not optimization.

**Blocked by:** M3.1. `needs-info` → `ready-for-agent`

### M3.4 — Splicing workbench UI

**What to build.** The workbench: assemble core + fragments, the shared
validator (capacity hard cap, costs), a firing range to test on, and
naming your creation. This is the "writing, not shopping" moment — the
player-facing anchors from VISION apply.

**Blocked by:** M3.2, M3.3. `needs-info` → `ready-for-agent`

### M3.5 — Spliced skills persist; drawbacks & costs

**What to build.** Spliced skills serialize with the character (validated
at the gate on load); drawback fragments and mana/cooldown cost scaling
close the loop that makes gear's coupling stats matter.

**Blocked by:** M3.4. `needs-info` → `ready-for-agent`

---

## Epic M4 — The journey, v1

> First real zone set with identity and vertical layout; zone mastery v1;
> gathering + Skillwright profession v1; first boss. **Exit: a 1–2 hour
> leveling journey that feels like the pitch.** Coarse on purpose — M4.1
> splits this epic when its time comes.

- **M4.1 — Design pass** (`ready-for-human`, blocked by Epic M3): zone set
  + Fallow enemy families (`docs/design/classes-and-oaths.md` open hooks);
  the difficulty-scaling decision (fixed zone levels vs scaling); whether
  rebuilding the Grounds is a formal meta-system — and with it, judgment
  day for the parked spatial charm board (`docs/design/stats-and-gear.md`
  open questions); briefs for M4.2–M4.5.
- **M4.2 — First zone set** with vertical layout (blocked by M4.1)
- **M4.3 — Zone mastery v1** (blocked by M4.2)
- **M4.4 — Gathering + Skillwright profession v1** (blocked by M4.2)
- **M4.5 — First boss** (blocked by M4.2)

---

## Epic M5 — Oaths & Scars (Lamplighter)

> The ascendancy system goes live for the first class. **Exit: two
> characters of the same class that build and play meaningfully differently
> because of what they did with their oath.** Source:
> `docs/design/classes-and-oaths.md`.

- **M5.1 — Design pass** (`ready-for-human`, blocked by Epic M4): Marks
  mechanic detail; minor-oath starter set; the scar-atonement decision
  (can a Scarred character re-swear?); briefs for the rest.
- **M5.2 — Minor-oath shrines** in the M4 zones: static build constraints,
  costly to unswear, no scars (blocked by M5.1)
- **M5.3 — Lamplighter base mechanic (Marks) + Oath of the Kept Flame**:
  the Lantern claims the relic slot; keystone light (blocked by M5.1)
- **M5.4 — Vowkeeper path: the Long Watch** exclusive tree (blocked by M5.3)
- **M5.5 — First Scar** (Snuffed Wick or False Beacon): ceremonial
  break-deed in the world, exclusive tree, signature effect, permanent
  static drawback; the Oathkeeper/Outcast NPC disposition split arrives
  with it (blocked by M5.3)

---

## Epic M6 — Second class + Bonds

> The Warden — planted melee against the Lamplighter's mobile ranged, the
> strongest proof of "class as starting point" — plus Bondmate milestones
> and bond invocation on the account layer. **Exit: a reason to roll
> character #2 that isn't boredom.**

- **M6.1 — Design pass** (`ready-for-human`, blocked by Epic M5): block as
  Warden class tech (parked in stats-and-gear.md); whether a Scarred
  Bondmate leaves a darker echo; briefs.
- **M6.2 — The Warden**: Foothold, Oath of the Unbroken Line, Vowkeeper
  tree, both Scars (blocked by M6.1)
- **M6.3 — Bonds v1** on the account layer: milestones, echoes, invocation
  (blocked by M6.1)

---

## Epic M7 — Endgame v1

> Mastery ceilings, oath-stacked challenges, boss gauntlet — evergreen
> endgame assembled from the pieces above, ending (for 1.0) at the First
> Oathbreaker. **Exit: die-hards have a min-max ceiling worth chasing.**

- **M7.1 — Design pass** (`ready-for-human`, blocked by Epic M6): splits
  the epic; includes the First Oathbreaker pinnacle fight design (the
  mirror of the player's own Scar system — their class and broken oath
  chosen per the open hook in `docs/design/classes-and-oaths.md`).
