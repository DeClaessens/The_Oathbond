class_name HighlightComponent
extends Node

## Purely presentational, opt-in per character (ADR-0007 style). Brightens
## the sibling Icon sprite's modulate; an outline shader is the eventual
## upgrade and would only touch this file. Never decides *whether* to glow
## -- TargetPreviewComponent decides; this just renders the toggle.

const HIGHLIGHT_MULTIPLIER := 1.6

var _highlighted: bool = false
var _sprite: CanvasItem
var _base_modulate: Color = Color.WHITE

static func of(node: Node) -> HighlightComponent:
    if node == null:
        return null
    return node.get_node_or_null(^"HighlightComponent") as HighlightComponent

func _ready() -> void:
    _sprite = get_parent().get_node_or_null(^"Icon") as CanvasItem
    if _sprite == null:
        push_error("HighlightComponent: no sibling Icon sprite found on %s, highlight is disabled" % get_parent())
        return
    _base_modulate = _sprite.modulate

func is_highlighted() -> bool:
    return _highlighted

func set_highlighted(on: bool) -> void:
    if _highlighted == on:
        return
    _highlighted = on
    if _sprite != null:
        _sprite.modulate = _base_modulate * HIGHLIGHT_MULTIPLIER if on else _base_modulate
