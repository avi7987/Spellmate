class_name PanelDecor
extends Control
## Decoration for a board (UiKit.panel()): a glossy band along the top and a
## thin coloured line inside the rim. Draws over the board, under the content.

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
	line.border_color = Color(accent.r, accent.g, accent.b, 0.35)
	line.set_border_width_all(2)
	line.set_corner_radius_all(15)
	draw_style_box(line, r)
