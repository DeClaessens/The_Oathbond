# Project status — single source of "where are we"

One page, always current. Any session (human or agent) starting work reads
this first instead of re-deriving state from git history. **Whoever merges a
story or closes a decision updates this file in the same commit.**

Last updated: 2026-07-08 (M2.2 + M2.5 merged).

## Where we are

- **M1 — Persistence is code-complete.** M1.2 (character save/load) merged
  to `main` 2026-07-08 after two-axis review; suite green (218/218). The M1
  exit criterion — quit and resume a character, account file exists — awaits
  Thomas's in-game quit→relaunch check.
- **M2 — Loot & inventory design pass (M2.1) done 2026-07-08.** ADR-0016
  (derived stats), ADR-0017 (crit), attribute names locked (Might/Grace/Wit),
  and four `ready-for-agent` briefs (M2.2–M2.5). M2.5 (crit & stat roster)
  merged 2026-07-08. M2.2 (attributes) merged 2026-07-08; M2.3 (drops &
  inventory) in progress. M2.4 (equip gate) unblocks once M2.3 merges.
- M0 (Combat completeness) merged 2026-07-07; its playable exit criterion
  lives in the proving-grounds level (`levels/`) with the Slime.

## Story ledger

| Story | What | State |
|-------|------|-------|
| M0.1 | Global cooldown | ✅ merged 2026-07-07 (`b06aee8`) |
| M0.2 | Target selection | ✅ merged 2026-07-07 (`81125d6`) |
| M0.3 | First real enemy + AI (Slime) | ✅ merged 2026-07-07 (`ccaa243`) |
| M0.4 | XP & character levels | ✅ merged 2026-07-07 (`f198c17`) |
| M0.5 | Target highlight | ✅ merged 2026-07-07 (`a050de9`) |
| M0.6 | FIRE→EMBER rename | ✅ done 2026-07-06 |
| M0.7 | **Decision:** death penalty model | 🟡 open — `ready-for-human` (Thomas). VISION leans "keep cheap respawn"; record the call in VISION's open questions. |
| M0.8 | Proving-grounds level + camera | ✅ merged 2026-07-07 (`da6f2dd`) |
| M1.1 | Design pass: save architecture | ✅ done 2026-07-08 — ADR-0015 + `docs/briefs/m1-02-character-save-load.md` |
| M1.2 | Character save/load | ✅ merged 2026-07-08 (`45f90eb`) — implemented by a coding agent, reviewed (standards + spec axes), review findings fixed |
| M2.1 | Design pass: M2 ADRs + briefs | ✅ done 2026-07-08 — ADR-0016, ADR-0017, briefs m2-02…m2-05, attribute names locked |
| M2.2 | Attributes (Might/Grace/Wit) | ✅ merged 2026-07-08 (`6133063`) — ADR-0016 derived stats (might→hp, wit→mana, grace→crit_multi) + AttributesComponent + allocation panel; suite 279/279 |
| M2.3 | Item drops & inventory | 🔵 `ready-for-agent` — dispatchable now (parallel wave 1) |
| M2.4 | Equip gate & slots | ⚪ `ready-for-agent` — blocked until M2.2 + M2.3 merge |
| M2.5 | Crit & new stat roster | ✅ merged 2026-07-08 (`6cbe257`) — crit via DamagePacket/roll_outgoing (ADR-0017), health_regen, CDR/MCR caps; suite 243/243 |
| M3+ | Skill splicing, journey, … | ⚪ not started — see `epics-and-stories.md` |

## Standing pointers

- Full story detail & acceptance criteria: `docs/plan/epics-and-stories.md`
- Specs/contracts for stories: `docs/briefs/`
- Dispatch prompts + agent working agreement: `docs/handoff/`
- Design backbone: `docs/VISION.md` · Domain language: `CONTEXT.md` · Decisions: `docs/adr/`

## Human queue (Thomas)

1. **M1 exit check** — play, gain a level, quit (window close — editor-stop
   doesn't save, by design), relaunch: level/XP/pools/equips resume. Closes
   Epic M1 and ungates the M2.1 design pass.
2. **M0.7 death-penalty decision** — the fight–die–level loop is playable;
   decide and close the VISION open question.
3. **Feel pass on M0** — GCD 0.4s cadence, Slime chase/bite tuning, camera
   feel. Tuned by play, not by test (`docs/handoff/README.md`).
