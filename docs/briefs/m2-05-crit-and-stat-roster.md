# M2-05 — Crit & the new stat roster

*Depends on M2.1 (ADR-0017). Independent of M2.2/M2.3/M2.4 — the affixes
these stats ride on come from M2.3's pools, but the *consumers* built here
work on base stats alone, so this can run in parallel and merge in any order.*

## Goal

Crits happen, feel good, and read differently in the combat text; and the
four reserved stat keys stop being dormant — flat added damage, health
regen, cooldown reduction, and mana-cost reduction all measurably change
play. This closes the stat roster the whole loot economy rolls against.
Design source: `docs/design/stats-and-gear.md` (Crit, Stat roster);
mechanism contract: ADR-0017.

## Design decisions (made — do not reopen)

1. **Implement ADR-0017 exactly:** the `DamagePacket` type, `StatsComponent.
   roll_outgoing(base, type) -> DamagePacket` (keeping `scale_outgoing` as
   the deterministic inner step), crit rolled from `CRIT_CHANCE`/`CRIT_MULTI`
   (clamped: chance to [0,1], multi floored at 1.0), and the `is_crit` flag
   threaded `apply_damage → Events.damage_dealt → CombatTextSpawner →
   FloatingCombatText`. Both damage call sites (`DamageEffect`,
   `SpawnProjectileEffect` → `Projectile`) route through `roll_outgoing`
   once; the projectile carries `is_crit` alongside `damage`.
2. **Crit base stats live on characters.** Add `crit_chance` (0.05) and
   `crit_multi` (1.5) to the player's authored `base_stats`
   (`Player.tscn`) and the Slime's (so enemies can crit too — ADR-0002).
   The `StatKeys.CRIT_CHANCE`/`CRIT_MULTI` constants already exist; this
   makes them read.
3. **`Events.damage_dealt` gains `is_crit: bool` (trailing).** Update the
   signal, `HealthComponent.apply_damage(raw, type, source, is_crit := false)`
   (default keeps non-crit and existing callers valid), and every connected
   handler. The FCT renders a crit with a larger scale and a distinct color
   (authored constants on `FloatingCombatText`); `play(amount, is_crit :=
   false)` selects the style.
4. **Flat added damage is a FLAT-op affix on `dmg_<type>` — no new key.**
   `scale_outgoing` already composes `(base + ΣFLAT) × (1+ΣADD%) × …` over
   the `dmg_<type>` mods, so a `StatModifier{stat: dmg_ember, op: FLAT,
   value: 10}` *is* "+10 flat Ember damage" and an `ADD_PCT` one is
   "+% increased Ember". This story's job is to **confirm both work end to
   end** and ensure M2.3's weapon pool authors FLAT `dmg_<type>` entries
   (coordinate: if M2.3 merged first, add the FLAT entries; if not, note it
   for M2.3). Do not invent a `dmg_flat_<type>` key — it would double the
   offense model for no gain.
5. **`health_regen`: give `HealthComponent` a regen loop** mirroring
   `ManaComponent`'s `_process` (read `StatKeys.HEALTH_REGEN`, add
   `regen * delta` up to `_max`, no regen while `_dead`). Base 0 (no free
   regen); the stat is an affix payoff. Emit `health_changed` only when the
   value actually moves (avoid a per-frame signal storm at full health).
6. **`cooldown_reduction`: applied to per-skill cooldowns, not the GCD.**
   When `AbilityComponent` starts a slot's cooldown after a successful cast,
   scale it: `effective := base_cd * (1.0 - clampf(caster_stats.get_stat(
   COOLDOWN_REDUCTION), 0.0, CDR_CAP))`, `CDR_CAP := 0.75`. The GCD is the
   tempo floor and is **not** reduced (design: cooldown_reduction is the
   speed stat, GCD is the cadence knob). Reads the caster's `StatsComponent`
   via `caster`.
7. **`mana_cost_reduction`: applied when spending.** Effective cost
   `base_cost * (1.0 - clampf(get_stat(MANA_COST_REDUCTION), 0.0, MCR_CAP))`,
   `MCR_CAP := 0.75`, checked in the affordability test *and* the actual
   spend so they never disagree (compute once, use for both). A skill with a
   `mana_cost` of 0 stays free.
8. **Caps are named constants** (`CDR_CAP`, `MCR_CAP`, resist cap already
   0.9) on their owning components — one place to tune, cited in CONTEXT.
   Crit chance has no cap beyond the [0,1] probability clamp; crit_multi is
   uncapped upward.

## Invariants to respect

- ADR-0017 is the contract: one `roll_outgoing` seam, crit flag survives to
  the FCT, resistance stays victim-side and composes after crit. The trap:
  re-rolling crit at two call sites, or consuming `is_crit` before it reaches
  the spawner.
- ADR-0004: `scale_outgoing` stays the deterministic `dmg_<type>` seam;
  crit sits outside it, not inside (a hidden roll makes damage
  non-deterministic and untestable).
- ADR-0002 symmetry: crit, regen, CDR, MCR are all read from whichever
  character's `StatsComponent` is acting — never special-cased to the player.
- Crit is random: test the boundaries (chance 0 / chance 1) and the
  multiplier identity, never a specific `randf()` outcome.
- Do not change the GCD (M0.1's contract) — CDR touches per-slot cooldowns
  only.

## Documentation this brief owes

- **CONTEXT.md**: **Crit** (a per-hit caster-side roll: `crit_chance` to
  occur, `crit_multi` for the payoff; rolled in the DamagePacket, flagged to
  the combat text — cite ADR-0017), **Damage Packet** (the outgoing
  `{amount, type, is_crit}` that replaced the bare float — cite ADR-0004/
  0017), and short entries for **Cooldown Reduction** (scales per-skill
  cooldowns to a cap, never the GCD) and **Mana-Cost Reduction**. Note the
  caps and that flat/%-added damage are just FLAT/ADD_PCT ops on
  `dmg_<type>` (no separate key).

## Acceptance criteria

- With `crit_chance = 1.0` every hit is a crit dealing
  `scale_outgoing(base) × crit_multi`; with `0.0` none do; the FCT shows
  crits visibly differently (scale + color) and normal hits unchanged.
- A projectile fired while `crit_chance = 1.0` lands as a crit (the flag
  survives spawn → collision → FCT).
- A `+FLAT dmg_ember` modifier raises an Ember skill's dealt damage by that
  flat amount before resistances; a `+ADD_PCT dmg_ember` raises it
  proportionally; the two compose per ADR-0001.
- `health_regen > 0` refills health over time up to max and never past it,
  and never while dead; regen 0 leaves health flat.
- `cooldown_reduction` measurably shortens a skill's cooldown (0.5 CDR →
  half), capped at `CDR_CAP`; the GCD duration is unchanged.
- `mana_cost_reduction` lowers both the affordability threshold and the mana
  actually spent by the same amount, capped at `MCR_CAP`.
- Enemies crit too (a Slime with `crit_chance = 1.0` crits the player).
- Full GUT suite green (new `class_name DamagePacket` ⇒ `--headless
  --import`; confirm new/changed test files appear).

## Test ideas

- Crit boundaries: `roll_outgoing` with chance 0 → `is_crit false`, amount
  == `scale_outgoing`; chance 1 → `is_crit true`, amount ==
  `scale_outgoing × crit_multi`; multi < 1 floored to 1.
- Flag threading: drive `apply_damage(…, is_crit=true)` and assert
  `Events.damage_dealt` carries it; spawner → `play` receives it (extend the
  existing combat-text spawner test).
- Flat vs % damage: `scale_outgoing(50, EMBER)` with a FLAT 10 → 60; with an
  ADD_PCT 0.2 → 60; both → 72.
- Health regen: entity below max with `health_regen`, tick `_process`,
  assert it rises and clamps; dead → no regen.
- CDR: cast with `cooldown_reduction = 0.5` → slot cooldown is half base;
  = 0.9 → clamped to `CDR_CAP`; GCD unchanged. MCR likewise on cost.

## Out of scope

- The affixes themselves being *rolled/authored into pools* (M2.3) — this
  story makes the stats **consumed**; it may add pool entries only to the
  extent decision 4 requires FLAT damage entries to exist for its own test.
- Crit for damage-over-time / status effects (none exist yet).
- Attack/cast speed, dodge, block (deliberately absent — design doc).
- Crit FCT beauty beyond scale+color (screen shake, sound).
- Per-damage-type crit or crit for healing.
- Rebalancing existing skill base numbers.
