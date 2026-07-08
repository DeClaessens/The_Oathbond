class_name AttributesPanel
extends CanvasLayer

## Minimal allocation panel (M2.2): read-then-command like the Skill Bar
## mirrors AbilityComponent. Reads AttributesComponent + StatsComponent,
## commands only allocate()/respec(). Toggled by `toggle_attributes` (C).
## Functional, not styled -- no tooltips or animation.

var _attributes: AttributesComponent
var _stats: StatsComponent

@onready var _panel: Control = $Panel
@onready var _unspent_label: Label = $Panel/MarginContainer/VBoxContainer/UnspentLabel
@onready var _might_label: Label = $Panel/MarginContainer/VBoxContainer/MightRow/MightLabel
@onready var _might_button: Button = $Panel/MarginContainer/VBoxContainer/MightRow/MightButton
@onready var _grace_label: Label = $Panel/MarginContainer/VBoxContainer/GraceRow/GraceLabel
@onready var _grace_button: Button = $Panel/MarginContainer/VBoxContainer/GraceRow/GraceButton
@onready var _wit_label: Label = $Panel/MarginContainer/VBoxContainer/WitRow/WitLabel
@onready var _wit_button: Button = $Panel/MarginContainer/VBoxContainer/WitRow/WitButton
@onready var _derived_label: Label = $Panel/MarginContainer/VBoxContainer/DerivedLabel
@onready var _respec_button: Button = $Panel/MarginContainer/VBoxContainer/RespecButton

func _ready() -> void:
    _panel.visible = false
    _might_button.pressed.connect(func() -> void: _attributes.allocate(StatKeys.MIGHT))
    _grace_button.pressed.connect(func() -> void: _attributes.allocate(StatKeys.GRACE))
    _wit_button.pressed.connect(func() -> void: _attributes.allocate(StatKeys.WIT))
    _respec_button.pressed.connect(func() -> void: _attributes.respec())

func bind(attributes: AttributesComponent, stats: StatsComponent) -> void:
    if _attributes != null:
        _attributes.attributes_changed.disconnect(_refresh)
        _attributes.points_changed.disconnect(_on_points_changed)
    _attributes = attributes
    _stats = stats
    attributes.attributes_changed.connect(_refresh)
    attributes.points_changed.connect(_on_points_changed)
    _refresh()

func is_open() -> bool:
    return _panel.visible

func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed(&"toggle_attributes"):
        _panel.visible = not _panel.visible

func _on_points_changed(_unspent: int) -> void:
    _refresh()

func _refresh() -> void:
    if _attributes == null or _stats == null:
        return
    var unspent := _attributes.unspent()
    _unspent_label.text = "Unspent points: %d" % unspent
    _might_label.text = "Might: %d" % int(_stats.get_stat(StatKeys.MIGHT))
    _grace_label.text = "Grace: %d" % int(_stats.get_stat(StatKeys.GRACE))
    _wit_label.text = "Wit: %d" % int(_stats.get_stat(StatKeys.WIT))
    _might_button.disabled = unspent <= 0
    _grace_button.disabled = unspent <= 0
    _wit_button.disabled = unspent <= 0
    _derived_label.text = "Max Health: %.0f    Max Mana: %.0f    Crit Multi: %.3f" % [
        _stats.get_stat(StatKeys.MAX_HEALTH),
        _stats.get_stat(StatKeys.MAX_MANA),
        _stats.get_stat(StatKeys.CRIT_MULTI),
    ]
