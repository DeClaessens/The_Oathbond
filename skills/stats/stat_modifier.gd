class_name StatModifier
extends RefCounted

enum Op {
    FLAT,
    ADD_PCT,
    MULT_PCT,
}

enum StackMode {
    REFRESH,
    STACK,
}

var stat: StringName
var op: Op = Op.MULT_PCT
var value: float = 0.0
var key: StringName = &""
var stack_mode: StackMode = StackMode.REFRESH
var max_stacks: int = 0
var duration: float = 0.0
var remaining: float = 0.0
var source: Object
