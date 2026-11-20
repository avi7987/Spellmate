class_name GameButton
extends Button
## A chunky mobile-game button: rounded, a bright colour with a darker
## "3D" edge under it and a glossy top; it pops a little under the mouse and
## sinks when pressed. `seal = true` makes it a big round button.

var tint := UiKit.BUTTON_BRONZE
var seal := false
var _glow := 0.0
var _hovered := false
var _plate: Control
var _time := randf() * 10.0
const DEPTH := 6.0


func _init(p_text: String = "", p_tint: Color = UiKit.BUTTON_BRONZE) -> void:
	text = p_text
	tint = p_tint
	for state_name in ["normal", "hover", "pressed", "disabled", "focus", "hover_pressed"]:
		var e := StyleBoxEmpty.new()
		e.content_margin_bottom = DEPTH
		e.content_margin_left = 12
		e.content_margin_right = 12
		add_theme_stylebox_override(state_name, e)
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
	if absf(_glow - target) > 0.001 or seal:
		_glow = move_toward(_glow, target, delta * 6.0)
		_plate.queue_redraw()


func _box(c: Color, radius: int, border: int = 3) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.border_color = UiKit.PANEL_EDGE
	sb.set_border_width_all(border)
	sb.set_corner_radius_all(radius)
	return sb


func _draw_plate() -> void:
	var down := button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	var c := tint
	if disabled:
		c = UiKit.BUTTON_GREY.darkened(0.2)
	elif _glow > 0.0:
		c = c.lightened(0.12 * _glow)
	if seal:
		_draw_round(c, down)
		return
	var sink := DEPTH if down else 0.0
	var r := Rect2(Vector2(0, sink), Vector2(size.x, size.y - DEPTH))
	var radius := int(minf(16.0, r.size.y * 0.35))
	# the darker edge under the button gives it depth
	if not down:
		_plate.draw_style_box(_box(c.darkened(0.45), radius), Rect2(Vector2(0, DEPTH), r.size))
	_plate.draw_style_box(_box(c, radius), r)
	# glossy top half
	var gloss := StyleBoxFlat.new()
	gloss.bg_color = Color(1, 1, 1, 0.22)
	gloss.corner_radius_top_left = radius - 3
	gloss.corner_radius_top_right = radius - 3
	gloss.corner_radius_bottom_left = 6
	gloss.corner_radius_bottom_right = 6
	_plate.draw_style_box(gloss, Rect2(r.position + Vector2(5, 4), Vector2(r.size.x - 10, r.size.y * 0.42)))


func _draw_round(c: Color, down: bool) -> void:
	var d := minf(size.x, size.y - DEPTH)
	var center := Vector2(size.x / 2.0, d / 2.0 + (DEPTH if down else 0.0))
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	if not disabled:
		_plate.draw_circle(center, d * 0.5 + 6 + 4 * pulse, Color(1.0, 0.8, 0.3, 0.25 + 0.2 * _glow))
	if not down:
		_plate.draw_circle(center + Vector2(0, DEPTH), d * 0.5, c.darkened(0.5))
	_plate.draw_circle(center, d * 0.5, UiKit.PANEL_EDGE)
	_plate.draw_circle(center, d * 0.5 - 4, c)
	_plate.draw_circle(center, d * 0.5 - 12, c.lightened(0.1))
	_plate.draw_circle(center + Vector2(0, -d * 0.18), d * 0.28, Color(1, 1, 1, 0.18))
	_plate.draw_arc(center, d * 0.5 - 12, 0, TAU, 48, UiKit.GOLD, 3.0, true)
