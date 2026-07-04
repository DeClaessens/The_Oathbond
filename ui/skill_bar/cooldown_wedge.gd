class_name CooldownWedge
extends Control

var _fraction: float = 0.0

func fraction() -> float:
    return _fraction

func set_fraction(f: float) -> void:
    _fraction = clampf(f, 0.0, 1.0)
    queue_redraw()

func _draw() -> void:
    if _fraction <= 0.0:
        return
    var center := size / 2.0
    var radius := maxf(size.x, size.y) / 2   # overshoot to cover corners
    var steps := 48
    var start := -PI / 2.0
    var end := start + TAU * _fraction
    var pts := PackedVector2Array([center])
    for i in steps + 1:
        var a := start + (end - start) * (float(i) / steps)
        pts.append(center + Vector2(cos(a), sin(a)) * radius)
    draw_colored_polygon(pts, Color(0, 0, 0, 0.6))
