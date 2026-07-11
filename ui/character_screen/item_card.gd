class_name ItemCard
extends PanelContainer

## The one card renderer for both the hover Tooltip and the pinned
## InspectPanel (BLUEPRINT.md) -- one renderer, zero drift. Renders an
## ItemInstance's name/rarity/slot, implicit + rolled mod lines, its
## attribute requirement, and (when `compare_to` is given) a "VS EQUIPPED"
## delta block. `mod_deltas` is a pure static helper so GUT can unit-test the
## arithmetic without touching a scene tree.

const RARITY_NAMES := {
    ItemTypes.Rarity.COMMON: "Common",
    ItemTypes.Rarity.QUALITY: "Quality",
    ItemTypes.Rarity.MASTERWORK: "Masterwork",
    ItemTypes.Rarity.HEIRLOOM: "Heirloom",
}

const RARITY_COLORS := {
    ItemTypes.Rarity.COMMON: Color(0.749, 0.749, 0.749),      # #BFBFBF
    ItemTypes.Rarity.QUALITY: Color(0.349, 0.8, 0.4),         # #59CC66
    ItemTypes.Rarity.MASTERWORK: Color(0.949, 0.780, 0.302),  # #F2C74D
    ItemTypes.Rarity.HEIRLOOM: Color(0.949, 0.549, 0.251),    # #F28C40
}

const SLOT_NAMES := {
    ItemTypes.ItemSlot.WEAPON: "Weapon",
    ItemTypes.ItemSlot.OFF_HAND: "Off-hand",
    ItemTypes.ItemSlot.HELM: "Helm",
    ItemTypes.ItemSlot.BODY: "Body",
    ItemTypes.ItemSlot.GLOVES: "Gloves",
    ItemTypes.ItemSlot.BOOTS: "Boots",
    ItemTypes.ItemSlot.BELT: "Belt",
    ItemTypes.ItemSlot.AMULET: "Amulet",
    ItemTypes.ItemSlot.RING: "Ring",
    ItemTypes.ItemSlot.RELIC: "Relic",
}

const STAT_DISPLAY_NAMES := {
    &"dmg_physical": "Physical Damage",
    &"dmg_ember": "Ember Damage",
    &"dmg_radiance": "Radiance Damage",
    &"dmg_rot": "Rot Damage",
    &"crit_chance": "Crit Chance",
    &"crit_multi": "Crit Multiplier",
    &"max_health": "Max Health",
    &"health_regen": "Health Regen",
    &"max_mana": "Max Mana",
    &"mana_regen": "Mana Regen",
    &"might": "Might",
    &"grace": "Grace",
    &"wit": "Wit",
    &"resist_physical": "Physical Resistance",
    &"resist_ember": "Ember Resistance",
    &"resist_radiance": "Radiance Resistance",
    &"resist_rot": "Rot Resistance",
    &"cooldown_reduction": "Cooldown Reduction",
    &"mana_cost_reduction": "Mana Cost Reduction",
}

const IMPLICIT_COLOR := Color(0.831, 0.463, 0.420)      # #d4756b
const AFFIX_COLOR := Color(0.624, 0.741, 0.812)         # #9fbdcf
const REQUIREMENT_COLOR := Color(0.949, 0.643, 0.302)   # #f2a44d
const REQUIREMENT_FAIL_COLOR := Color(0.878, 0.424, 0.353)  # #E06C5A
const GAIN_COLOR := Color(0.349, 0.8, 0.4)              # #59CC66
const LOSS_COLOR := Color(0.878, 0.424, 0.353)          # #E06C5A
const MUTED_COLOR := Color(0.541, 0.576, 0.612)         # #8a939e

var _stats: StatsComponent

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _sub_label: Label = $Margin/VBox/SubLabel
@onready var _mods_box: VBoxContainer = $Margin/VBox/ModsBox
@onready var _requirement_label: Label = $Margin/VBox/RequirementLabel
@onready var _comparison_box: VBoxContainer = $Margin/VBox/ComparisonBox

## Lets the requirement line render red when the bound character fails it.
## Optional -- the card still works (just never shows the fail color) with
## no StatsComponent bound, e.g. in isolated tests.
func bind_stats(stats: StatsComponent) -> void:
    _stats = stats

func set_item(item: ItemInstance, compare_to: ItemInstance = null, validation: EquipResult = null) -> void:
    for child in _mods_box.get_children():
        child.queue_free()
    for child in _comparison_box.get_children():
        child.queue_free()

    if item == null:
        _name_label.text = ""
        _sub_label.text = ""
        _requirement_label.hide()
        _comparison_box.hide()
        return

    var def := item.definition()
    _name_label.text = def.display_name if def != null else String(item.definition_id)
    _name_label.add_theme_color_override("font_color", RARITY_COLORS.get(item.rarity, Color.WHITE))

    var rarity_name: String = RARITY_NAMES.get(item.rarity, "?")
    var slot_name: String = SLOT_NAMES.get(def.slot, "?") if def != null else "?"
    _sub_label.text = "%s · %s" % [rarity_name, slot_name]
    _sub_label.add_theme_color_override("font_color", MUTED_COLOR)

    if def != null:
        for entry in def.implicit_mods:
            _mods_box.add_child(_mod_line(ItemAffix.triple(entry), IMPLICIT_COLOR))
    for affix in item.rolled_affixes:
        _mods_box.add_child(_mod_line(ItemAffix.triple(affix), AFFIX_COLOR))

    var requirement: Dictionary = def.attribute_requirement if def != null else {}
    if requirement.is_empty():
        _requirement_label.hide()
    else:
        _requirement_label.show()
        var lines: Array[String] = []
        for attr in requirement:
            var required: float = float(requirement[attr])
            lines.append("Requires %s %s" % [_stat_display_name(StringName(attr)), _format_number(required)])
        _requirement_label.text = ", ".join(lines)
        var fails := validation != null and validation.reason == &"requirements_not_met"
        _requirement_label.add_theme_color_override("font_color", REQUIREMENT_FAIL_COLOR if fails else REQUIREMENT_COLOR)

    if compare_to == null:
        _comparison_box.hide()
        return

    _comparison_box.show()
    var separator := HSeparator.new()
    _comparison_box.add_child(separator)
    var header := Label.new()
    header.text = "VS EQUIPPED"
    header.add_theme_color_override("font_color", MUTED_COLOR)
    _comparison_box.add_child(header)

    var equipped_def := compare_to.definition()
    var equipped_name := Label.new()
    equipped_name.text = equipped_def.display_name if equipped_def != null else String(compare_to.definition_id)
    equipped_name.add_theme_color_override("font_color", RARITY_COLORS.get(compare_to.rarity, Color.WHITE))
    _comparison_box.add_child(equipped_name)

    for delta in mod_deltas(item, compare_to):
        _comparison_box.add_child(_delta_line(delta))

func _mod_line(triple: Dictionary, color: Color) -> Label:
    var label := Label.new()
    label.text = _format_mod(triple.stat, triple.op, triple.value)
    label.add_theme_color_override("font_color", color)
    return label

func _delta_line(delta: Dictionary) -> HBoxContainer:
    var row := HBoxContainer.new()
    var text := Label.new()
    text.text = _format_mod(delta.stat, delta.op, absf(delta.delta), delta.gain)
    text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text.add_theme_color_override("font_color", AFFIX_COLOR)
    row.add_child(text)
    var arrow := Label.new()
    arrow.text = "▲" if delta.gain else "▼"
    arrow.add_theme_color_override("font_color", GAIN_COLOR if delta.gain else LOSS_COLOR)
    row.add_child(arrow)
    return row

## Renders one stat/op/value triple the way the old InventoryPanel's
## `_affix_text` did (FLAT -> `+%.1f`, pct ops -> `+%.0f%%`), with a display
## name instead of the raw StringName, and an explicit sign for delta lines
## (`force_sign_for_delta` true means the caller already knows gain/loss).
func _format_mod(stat: StringName, op: StatModifier.Op, value: float, gain: Variant = null) -> String:
    var sign_str := "+"
    if gain != null and gain == false:
        sign_str = "−"
    var value_str: String
    match op:
        StatModifier.Op.FLAT:
            value_str = "%s%.1f" % [sign_str, value]
        StatModifier.Op.ADD_PCT, StatModifier.Op.MULT_PCT:
            value_str = "%s%.0f%%" % [sign_str, value * 100.0]
        _:
            value_str = "%s%s" % [sign_str, value]
    return "%s %s" % [value_str, _stat_display_name(stat)]

func _format_number(value: float) -> String:
    if is_equal_approx(value, roundf(value)):
        return str(int(round(value)))
    return str(value)

func _stat_display_name(stat: StringName) -> String:
    return STAT_DISPLAY_NAMES.get(stat, String(stat))

## Aggregates one ItemInstance's mods (implicits + rolled) by (stat, op).
## FLAT and ADD_PCT combine additively; MULT_PCT stores the equivalent
## compounded modifier value so the displayed comparison matches
## StatsComponent's composition formula.
static func _aggregate(item: ItemInstance) -> Dictionary:
    var out := {}
    if item == null:
        return out
    var def := item.definition()
    var sources: Array = []
    if def != null:
        sources.append_array(def.implicit_mods)
    sources.append_array(item.rolled_affixes)
    for src in sources:
        var triple := ItemAffix.triple(src)
        var key := "%s|%d" % [String(triple.stat), int(triple.op)]
        if out.has(key):
            if triple.op == StatModifier.Op.MULT_PCT:
                out[key].value = (1.0 + out[key].value) * (1.0 + triple.value) - 1.0
            else:
                out[key].value += triple.value
        else:
            out[key] = {"stat": triple.stat, "op": triple.op, "value": triple.value}
    return out

## The delta arithmetic (Delta rules, BLUEPRINT.md): candidate's aggregated
## mods minus equipped's, per (stat, op) key. A positive delta is a gain, a
## negative one a loss (rendered as its own magnitude), a zero delta is
## omitted, and a key only one side has still nets out as a pure gain/loss.
## `equipped == null` (no comparable equipped item) still runs correctly --
## it aggregates to `{}`, so every candidate mod nets as a pure gain -- but
## callers should prefer not showing a comparison block at all in that case
## (BLUEPRINT.md: "No equipped item -> no comparison block").
static func mod_deltas(candidate: ItemInstance, equipped: ItemInstance) -> Array:
    var cand := _aggregate(candidate)
    var equip := _aggregate(equipped)
    var keys := {}
    for k in cand:
        keys[k] = true
    for k in equip:
        keys[k] = true

    var out: Array = []
    for key in keys:
        var c_entry: Dictionary = cand.get(key, {})
        var e_entry: Dictionary = equip.get(key, {})
        var c_val: float = float(c_entry.get("value", 0.0))
        var e_val: float = float(e_entry.get("value", 0.0))
        var stat: StringName = c_entry.get("stat", e_entry.get("stat"))
        var op: StatModifier.Op = c_entry.get("op", e_entry.get("op"))
        var delta := c_val - e_val
        if absf(delta) < 0.0001:
            continue
        out.append({"stat": stat, "op": op, "delta": delta, "gain": delta > 0.0})
    return out
