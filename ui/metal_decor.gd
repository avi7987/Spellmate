class_name MetalDecor
extends Control
## Decoration for a metal panel: rivets in the corners and a faint line of
## glowing runes along the top edge. Add it as the first child of a
## PanelContainer (UiKit.panel() does this): it draws over the panel but under
## the content that comes after it.

var accent := Color(0.45, 0.8, 1.0)
var margin := 16.0
var _time := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	# The decor fills the panel's content area; the panel edge is `margin` further out.
	var r := Rect2(Vector2(-margin, -margin), size + Vector2(margin, margin) * 2.0)
	for c in [Vector2(10, 10), Vector2(r.size.x - 10, 10), Vector2(10, r.size.y - 10), Vector2(r.size.x - 10, r.size.y - 10)]:
		draw_circle(r.position + c, 3.2, Color(0.5, 0.4, 0.26))
		draw_circle(r.position + c - Vector2(1, 1), 1.2, Color(0.95, 0.85, 0.6, 0.6))
	# Rune line on the top edge
	var y := r.position.y + 6.0
	var count := int((r.size.x - 60.0) / 22.0)
	for i in count:
		var x := r.position.x + 30.0 + i * 22.0
		var a := 0.15 + 0.25 * (0.5 + 0.5 * sin(_time * 2.0 + i * 0.7))
		var col := Color(accent.r, accent.g, accent.b, a)
		match i % 3:
			0: draw_line(Vector2(x, y - 3), Vector2(x + 6, y + 3), col, 1.5)
			1: draw_line(Vector2(x, y + 3), Vector2(x + 3, y - 3), col, 1.5); draw_line(Vector2(x + 3, y - 3), Vector2(x + 6, y + 3), col, 1.5)
			_: draw_line(Vector2(x + 3, y - 3), Vector2(x + 3, y + 3), col, 1.5)
