class_name StatModifier
extends RefCounted

## One modifier on one named stat. The caller holds the object; StatsComponent
## owns its lifetime once added. Runtime state (remaining) lives HERE, never on a
## Resource. `value` meaning depends on `op` (see below).

enum Op {
    FLAT,       ## value is an absolute amount added to the base
    ADD_PCT,    ## value is a fraction; 0.5 => +50% (additive bucket)
    MULT_PCT,   ## value is a fraction; 0.5 => ×1.5 (multiplicative bucket)
}

## How re-applying a modifier that shares this one's `key` behaves.
enum StackMode {
    REFRESH,    ## reset the duration window; magnitude does NOT compound (implemented)
    STACK,      ## add another independent entry, up to max_stacks   (RESERVED — see §3.5)
}

var stat: StringName
var op: Op = Op.MULT_PCT
var value: float = 0.0

## Grouping tag for timed buffs (e.g. &"sprint"). Empty = ungrouped
## (permanent gear/talent modifiers that never expire and never dedup).
var key: StringName = &""
var stack_mode: StackMode = StackMode.REFRESH
var max_stacks: int = 0          ## 0 = uncapped. RESERVED — used only by STACK mode.

var duration: float = 0.0        ## <= 0 => permanent (never ticked, never expires)
var remaining: float = 0.0       ## runtime; set/decremented by StatsComponent
var source: Object               ## the effect/gear that created it; for debugging
