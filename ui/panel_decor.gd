class_name PanelDecor
extends Control
## Decoration for a board (UiKit.panel()): a soft sheen along the top, a thin
## gold line inside the rim and a little gold crown on top (the royal style).

var accent := UiKit.GOLD
var margin := 22.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2(-margin, -margin), size + Vector2(margin, margin) * 2.0).grow(-6)
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.07)
	gloss.corner_radius_top_left = 16
	gloss.corner_radius_top_right = 16
	gloss.corner_radius_bottom_left = 6
	gloss.corner_radius_bottom_right = 6
	draw_style_box(gloss, Rect2(r.position, Vector2(r.size.x, minf(70.0, r.size.y * 0.3))))
	var line := StyleBoxFlat.new()
	line.bg_color = Color(0, 0, 0, 0)
	line.border_color = Color(accent.r, accent.g, accent.b, 0.75)
	line.set_border_width_all(2)
	line.set_corner_radius_all(15)
	draw_style_box(line.duplicate(), r.grow(-4))
	if crown:
		draw_crown(self, Vector2(size.x / 2.0, -margin - 2.0), 22.0)


var crown := true


## A small gold crown with three jewels (used on boards and buttons).
static func draw_crown(ci: CanvasItem, c: Vector2, s: float) -> void:
	var pts := PackedVector2Array([c + Vector2(-1, 0.5) * s, c + Vector2(-1, -0.35) * s, c + Vector2(-0.5, 0.05) * s,
		c + Vector2(0, -0.6) * s, c + Vector2(0.5, 0.05) * s, c + Vector2(1, -0.35) * s, c + Vector2(1, 0.5) * s])
	ci.draw_colored_polygon(pts, Color(1.0, 0.8, 0.25))
	ci.draw_rect(Rect2(c + Vector2(-1, 0.3) * s, Vector2(2, 0.25) * s), Color(0.85, 0.6, 0.12))
	pts.append(pts[0])
	ci.draw_polyline(pts, UiKit.OUTLINE, 3.0, true)
	for p in [Vector2(-1, -0.35), Vector2(0, -0.6), Vector2(1, -0.35)]:
		ci.draw_circle(c + p * s, s * 0.13, Color(1.0, 0.93, 0.6))
	ci.draw_circle(c + Vector2(0, 0.12) * s, s * 0.13, Color(0.85, 0.1, 0.15))
