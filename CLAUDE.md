## Agent skills

### Issue tracker

Issues live in GitHub Issues (`gh` CLI); external PRs are not treated as a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Default label vocabulary — `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix` — matching the canonical role names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout — one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.

### Implementation briefs

Fully-specified work packages live in `docs/briefs/` (staged there until `gh` is available; they are meant to become GitHub issues). Implement from the brief; if reality contradicts it, stop and re-plan instead of improvising.

### Project status

Where the project stands — milestone in progress, story ledger, what's next,
the human decision queue — lives in `docs/plan/STATUS.md`. Read it before
asking "what's done?" or planning next steps; update it in the same commit
that merges a story or closes a decision.

### Game vision & roadmap

The design backbone — pillars, signature systems (Skill Splicing, Oaths & Scars, Bonds), structural decisions, and the milestone roadmap — lives in `docs/VISION.md`. Read it before planning any new system or feature work.

## Code style

Always use spaces for indentation, never tabs.
