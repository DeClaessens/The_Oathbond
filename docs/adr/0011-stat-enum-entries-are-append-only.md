# New StatKeys.Stat entries are always appended, never inserted

`StatKeys.Stat` is the Inspector-only authoring enum ADR-0005 introduced; `.tres` files serialize it as a raw int, so an entry's position *is* its identity to every authored asset. Adding `MAX_MANA` and `MANA_REGEN` for the mana feature went to the end of the enum, after `RESISTANCE`, rather than next to `MAX_HEALTH` where they'd read more logically grouped with the other pool-ceiling stat. ADR-0005 already named this risk in passing; this ADR makes it a standing rule instead of something each future change has to rediscover: new `Stat` entries are always appended at the end, never inserted for grouping or readability, for as long as `.tres` stores this enum as a raw int.

## Consequences

- `Stat` enum ordering will drift away from any "logical" grouping over time — that's expected and correct, not a smell to clean up.
- If this enum is ever migrated to a string-keyed or otherwise position-independent representation, this rule becomes moot and can be dropped.
