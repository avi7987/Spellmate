class_name BookDecor
extends Control
## Decoration for a parchment page: gold corner flourishes and a small
## ornament at the top. Add it as the first child of a PanelContainer
## (UiKit.panel() does this): it draws over the page but under the content.

var accent := UiKit.GOLD
var margin := 30.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2(-margin, -margin), size + Vector2(margin, margin) * 2.0).grow(-16)
	var gold := UiKit.GOLD_DARK
	var ink := Color(UiKit.INK.r, UiKit.INK.g, UiKit.INK.b, 0.5)
	# double frame line
	draw_rect(r, Color(gold.r, gold.g, gold.b, 0.65), false, 2.0)
	draw_rect(r.grow(-5), Color(ink.r, ink.g, ink.b, 0.35), false, 1.0)
	# corner flourishes
	for corner in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
			[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
		var p: Vector2 = corner[0]
		var s: Vector2 = corner[1]
		var pts := PackedVector2Array()
		for i in 13:
			var a := i / 12.0 * PI * 1.5
			pts.append(p + Vector2(10 + cos(a) * 9.0, 10 + sin(a) * 9.0) * s)
		draw_polyline(pts, accent.darkened(0.25), 2.5, true)
		draw_circle(p + Vector2(10, 10) * s, 3.0, accent.darkened(0.15))
		draw_line(p + Vector2(22, 4) * s, p + Vector2(46, 4) * s, accent.darkened(0.25), 2.0, true)
		draw_line(p + Vector2(4, 22) * s, p + Vector2(4, 46) * s, accent.darkened(0.25), 2.0, true)
	# top ornament: a small diamond with two curls
	var c := Vector2(r.get_center().x, r.position.y)
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -7), c + Vector2(7, 0), c + Vector2(0, 7), c + Vector2(-7, 0)]), accent)
	for sgn in [-1.0, 1.0]:
		var pts := PackedVector2Array()
		for i in 11:
			var a := i / 10.0 * PI
			pts.append(c + Vector2(sgn * (12 + i * 2.4), -sin(a) * 5.0))
		draw_polyline(pts, accent.darkened(0.2), 2.0, true)
