class_name RuneButton
extends Button
## A dark forged-iron button with bevelled corners, rivets and runes that
## glow when the mouse is over it (dark medieval UI style).

var accent := Color(0.45, 0.8, 1.0)
var _glow := 0.25
var _hovered := false
var _plate: Control
var _time := randf() * 10.0


func _init(p_text: String = "", p_accent: Color = Color(0.45, 0.8, 1.0)) -> void:
	text = p_text
	accent = p_accent
	for state_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	_plate = Control.new()
	_plate.show_behind_parent = true
	_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plate.set_anchors_preset(Control.PRESET_FULL_RECT)
	_plate.draw.connect(_draw_plate)
	add_child(_plate)
	mouse_entered.connect(func(): _hovered = true)
	mouse_exited.connect(func(): _hovered = false)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _process(delta: float) -> void:
	_time += delta
	var target := 1.0 if _hovered and not disabled else (0.0 if disabled else 0.3)
	_glow = move_toward(_glow, target, delta * 4.0)
	_plate.queue_redraw()


func _octagon(r: Rect2, cut: float) -> PackedVector2Array:
	return PackedVector2Array([
		r.position + Vector2(cut, 0), Vector2(r.end.x - cut, r.position.y), Vector2(r.end.x, r.position.y + cut),
		Vector2(r.end.x, r.end.y - cut), Vector2(r.end.x - cut, r.end.y), Vector2(r.position.x + cut, r.end.y),
		Vector2(r.position.x, r.end.y - cut), Vector2(r.position.x, r.position.y + cut)])


func _draw_plate() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var down := button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if down:
		r = r.grow(-1)
	var pulse := 0.85 + 0.15 * sin(_time * 3.0)
	var a := accent
	# Outer glow when hovered
	if _glow > 0.05:
		for i in 3:
			var g := _octagon(r.grow(2 + i * 3), 10 + i * 2)
			g.append(g[0])
			_plate.draw_polyline(g, Color(a.r, a.g, a.b, 0.18 * _glow / (i + 1)), 4.0, true)
	# Iron plate with a top-to-bottom shade
	var top := Color(0.27, 0.27, 0.30) if not disabled else Color(0.18, 0.18, 0.19)
	var bottom := Color(0.10, 0.10, 0.12)
	var pts := _octagon(r, 10)
	var cols := PackedColorArray()
	for p in pts:
		cols.append(top.lerp(bottom, p.y / maxf(1.0, r.size.y)))
	_plate.draw_polygon(pts, cols)
	# Bronze rim and an inner highlight line
	var rim := pts.duplicate()
	rim.append(pts[0])
	_plate.draw_polyline(rim, UiKit.PANEL_BORDER.darkened(0.15 if not disabled else 0.5), 2.5, true)
	var inner := _octagon(r.grow(-5), 7)
	inner.append(inner[0])
	_plate.draw_polyline(inner, Color(1, 1, 1, 0.07), 1.0, true)
	# Rivets in the corners
	for c in [Vector2(9, 9), Vector2(r.size.x - 9, 9), Vector2(9, r.size.y - 9), Vector2(r.size.x - 9, r.size.y - 9)]:
		_plate.draw_circle(r.position + c, 2.6, Color(0.55, 0.45, 0.3))
		_plate.draw_circle(r.position + c - Vector2(0.8, 0.8), 1.0, Color(0.9, 0.8, 0.6, 0.6))
	# Runes on both sides: they light up on hover
	var rune_col := Color(a.r, a.g, a.b, (0.25 + 0.75 * _glow) * pulse) if not disabled else Color(0.3, 0.3, 0.3, 0.3)
	for side in [0.0, 1.0]:
		var x: float = lerpf(r.position.x + 20.0, r.end.x - 20.0, side)
		_draw_rune(Vector2(x, r.get_center().y), rune_col, int(side) + int(text.length()) % 3)


## Little angular glyphs, like carved runes.
func _draw_rune(c: Vector2, col: Color, variant: int) -> void:
	var h := minf(size.y * 0.22, 9.0)
	match variant % 3:
		0:
			_plate.draw_polyline(PackedVector2Array([c + Vector2(0, -h), c + Vector2(0, h)]), col, 2.0, true)
			_plate.draw_polyline(PackedVector2Array([c + Vector2(0, -h * 0.4), c + Vector2(h * 0.6, -h), ]), col, 2.0, true)
			_plate.draw_polyline(PackedVector2Array([c + Vector2(0, 0), c + Vector2(h * 0.6, -h * 0.4)]), col, 2.0, true)
		1:
			_plate.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.5, h), c + Vector2(0, -h), c + Vector2(h * 0.5, h)]), col, 2.0, true)
			_plate.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.3, h * 0.2), c + Vector2(h * 0.3, h * 0.2)]), col, 2.0, true)
		_:
			_plate.draw_polyline(PackedVector2Array([c + Vector2(-h * 0.5, -h), c + Vector2(h * 0.5, h), c + Vector2(-h * 0.5, h), c + Vector2(h * 0.5, -h)]), col, 2.0, true)
