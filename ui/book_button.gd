class_name BookButton
extends Button
## A button from the spellbook: stitched leather (tinted) or a paper slip,
## with gold corner studs; it glows warmly and lifts a little under the mouse.
## `seal = true` makes it a round red wax seal (the main action).

var tint := UiKit.BUTTON_BRONZE
var seal := false
var _glow := 0.0
var _hovered := false
var _plate: Control
var _time := randf() * 10.0


func _init(p_text: String = "", p_tint: Color = UiKit.BUTTON_BRONZE) -> void:
	text = p_text
	tint = p_tint
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
	var target := 1.0 if _hovered and not disabled else 0.0
	_glow = move_toward(_glow, target, delta * 5.0)
	_plate.queue_redraw()


func _draw_plate() -> void:
	var r := Rect2(Vector2.ZERO, size)
	var down := button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	if down:
		r = r.grow(-2)
	elif _glow > 0.0:
		r = r.grow(_glow * 1.5)
	var dim := Color(0.55, 0.5, 0.48) if disabled else Color.WHITE
	if seal:
		_draw_seal(r, dim)
		return
	# warm glow behind
	if _glow > 0.02:
		for i in 3:
			_plate.draw_rect(r.grow(2 + i * 3), Color(1.0, 0.75, 0.3, 0.10 * _glow / (i + 1)), false, 4.0)
	var sb: StyleBoxTexture
	if tint.a == 0.0:
		sb = StyleBoxTexture.new()
		sb.texture = UiKit.TEX_PAPER
		sb.set_texture_margin_all(16)
	else:
		sb = UiKit.leather_style(tint)
	sb.modulate_color *= dim
	_plate.draw_style_box(sb, r)
	# gold studs in the corners and a thin gold line
	var gold := UiKit.GOLD.lerp(Color(1, 0.95, 0.75), _glow * 0.5) * dim
	if tint.a > 0.0:
		_plate.draw_rect(r.grow(-4), Color(gold.r, gold.g, gold.b, 0.55), false, 1.5)
	for c in [Vector2(7, 7), Vector2(r.size.x - 7, 7), Vector2(7, r.size.y - 7), Vector2(r.size.x - 7, r.size.y - 7)]:
		var p: Vector2 = r.position + c
		var d := PackedVector2Array([p + Vector2(0, -4), p + Vector2(4, 0), p + Vector2(0, 4), p + Vector2(-4, 0)])
		_plate.draw_colored_polygon(d, gold)


func _draw_seal(r: Rect2, dim: Color) -> void:
	var d := minf(r.size.x, r.size.y)
	var rect := Rect2(r.get_center() - Vector2(d, d) / 2.0, Vector2(d, d))
	if _glow > 0.02 or not disabled:
		var pulse := 0.5 + 0.5 * sin(_time * 3.0)
		_plate.draw_circle(rect.get_center(), d * 0.52, Color(1.0, 0.7, 0.3, (0.12 + 0.18 * _glow) * (0.6 + 0.4 * pulse)))
	_plate.draw_texture_rect(UiKit.TEX_SEAL, rect, false, dim)
	# a gilded ring
	_plate.draw_arc(rect.get_center(), d * 0.31, 0, TAU, 48, Color(UiKit.GOLD.r, UiKit.GOLD.g, UiKit.GOLD.b, 0.55) * dim, 2.0, true)
