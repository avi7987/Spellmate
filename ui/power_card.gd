class_name PowerCard
extends Control
## A collectible-style card for one super power. Each power has its own colours
## and a hand-drawn (vector) illustration. Clicking the card activates the power.
##
## Layout (top to bottom): art window with the icon, name ribbon, description,
## footer with energy cost and cooldown. Disabled cards are darkened with a reason.

signal activated

const W := 236.0
const H := 330.0
const BRONZE := Color(0.72, 0.54, 0.26)
const BRONZE_DARK := Color(0.30, 0.20, 0.08)
const PARCHMENT := Color(0.93, 0.86, 0.70)

var ability_id := ""
var title := ""
var description := ""
var cost := 0
var status_text := ""
var usable := false
var active := false   ## true while choosing a target

var _hover := false
var _desc_label: Label
var _title_font: Font
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	size = Vector2(W, H)
	pivot_offset = Vector2(W, H) / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_title_font = UiKit.title_font()
	_desc_label = Label.new()
	_desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_desc_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_desc_label.position = Vector2(18, 214)
	_desc_label.size = Vector2(W - 36, 76)
	_desc_label.add_theme_font_override("font", UiKit.body_font())
	_desc_label.add_theme_font_size_override("font_size", 15)
	_desc_label.add_theme_color_override("font_color", Color(0.18, 0.12, 0.06))
	_desc_label.add_theme_constant_override("outline_size", 0)
	_desc_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_desc_label)
	mouse_entered.connect(func(): _hover = true; _animate_hover())
	mouse_exited.connect(func(): _hover = false; _animate_hover())


func setup(p_id: String, p_title: String, p_desc: String, p_cost: int, p_status: String, p_usable: bool, p_active: bool) -> void:
	ability_id = p_id
	title = p_title
	description = p_desc
	cost = p_cost
	status_text = p_status
	usable = p_usable
	active = p_active
	_desc_label.text = description
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if usable else Control.CURSOR_ARROW
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if usable or active:
		queue_redraw()


func _animate_hover() -> void:
	var tw := create_tween().set_parallel(true)
	var up := _hover and usable
	tw.tween_property(self, "scale", Vector2.ONE * (1.04 if up else 1.0), 0.15)
	tw.tween_property(self, "rotation_degrees", -1.5 if up else 0.0, 0.15)


func _gui_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed and usable:
		var tw := create_tween()
		tw.tween_property(self, "scale", Vector2.ONE * 0.95, 0.06)
		tw.tween_property(self, "scale", Vector2.ONE * 1.04, 0.1)
		activated.emit()
		accept_event()


# ------------------------------------------------------------ drawing

func _theme() -> Dictionary:
	return Style.POWER_THEME.get(ability_id, { "color": Color.WHITE, "dark": Color.BLACK, "icon": "" })


func _draw() -> void:
	var th := _theme()
	var c: Color = th["color"]
	var dark: Color = th["dark"]
	var r := Rect2(Vector2.ZERO, Vector2(W, H))
	# Glow when usable / active
	if usable or active:
		var glow := 0.35 + 0.25 * sin(_time * 3.0) if active else (0.35 if _hover else 0.18)
		for i in 4:
			var g := r.grow(3 + i * 3)
			draw_style_box(_box(Color(c.r, c.g, c.b, glow / (i + 1)), Color(0, 0, 0, 0), 0, 18 + i * 3), g)
	# Outer bronze frame and inner card body
	draw_style_box(_box(BRONZE_DARK, BRONZE, 4, 16), r)
	var body := r.grow(-8)
	draw_style_box(_box(dark, BRONZE_DARK, 2, 11), body)
	# Art window: vertical gradient + radial glow + icon
	var art := Rect2(16, 16, W - 32, 168)
	_gradient_rect(art, c.darkened(0.35), dark.darkened(0.2))
	var center := art.get_center() + Vector2(0, -4)
	for i in 6:
		draw_circle(center, 70.0 - i * 11.0, Color(c.r, c.g, c.b, 0.06 + i * 0.025))
	_draw_rays(center, c)
	_draw_icon(th["icon"], center, c)
	draw_rect(art, BRONZE, false, 3.0)
	# Name ribbon
	var rib := Rect2(6, art.end.y - 8, W - 12, 40)
	var pts := PackedVector2Array([rib.position, Vector2(rib.end.x, rib.position.y),
		Vector2(rib.end.x - 12, rib.get_center().y), rib.end, Vector2(rib.position.x, rib.end.y),
		Vector2(rib.position.x + 12, rib.get_center().y)])
	draw_colored_polygon(pts, Color(0.42, 0.10, 0.08))
	draw_polyline(pts + PackedVector2Array([pts[0]]), BRONZE, 2.0)
	draw_string(_title_font, Vector2(rib.position.x, rib.get_center().y + 9), title,
		HORIZONTAL_ALIGNMENT_CENTER, rib.size.x, 24, Color(1.0, 0.92, 0.7))
	# Parchment for the description
	var parch := Rect2(16, 210, W - 32, 84)
	draw_style_box(_box(PARCHMENT, BRONZE_DARK, 1, 6), parch)
	# Footer: cost gem (left) + status (right side)
	var gem_c := Vector2(36, H - 22)
	var gem := PackedVector2Array([gem_c + Vector2(0, -17), gem_c + Vector2(15, 0), gem_c + Vector2(0, 17), gem_c + Vector2(-15, 0)])
	draw_colored_polygon(gem, Color(0.25, 0.6, 1.0))
	draw_polyline(gem + PackedVector2Array([gem[0]]), Color(0.85, 0.95, 1.0), 2.0)
	draw_string(_title_font, gem_c + Vector2(-15, 7), str(cost), HORIZONTAL_ALIGNMENT_CENTER, 30, 19, Color.WHITE)
	draw_string(UiKit.body_font(), Vector2(60, H - 15), status_text, HORIZONTAL_ALIGNMENT_RIGHT, W - 78, 15,
		Color(1.0, 0.9, 0.6) if usable else Color(0.75, 0.7, 0.65))
	# Darken when it cannot be used
	if not usable and not active:
		draw_style_box(_box(Color(0.05, 0.04, 0.05, 0.5), Color(0, 0, 0, 0), 0, 14), r.grow(-4))


func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	return sb


func _gradient_rect(rect: Rect2, top: Color, bottom: Color) -> void:
	var pts := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	draw_polygon(pts, PackedColorArray([top, top, bottom, bottom]))


func _draw_rays(center: Vector2, c: Color) -> void:
	var spin := _time * 0.2
	for i in 12:
		var a := TAU * i / 12.0 + spin
		var d := Vector2(cos(a), sin(a))
		var side := Vector2(-d.y, d.x) * 7.0
		draw_colored_polygon(PackedVector2Array([center + d * 22.0 + side, center + d * 22.0 - side, center + d * 80.0]),
			Color(c.r, c.g, c.b, 0.10))


# ------------------------------------------------------------ icons

func _draw_icon(icon: String, p: Vector2, c: Color) -> void:
	var light := c.lightened(0.45)
	var ink := Color(0.08, 0.05, 0.03)
	match icon:
		"shield":  # heraldic shield with a crown
			var pts := PackedVector2Array([p + Vector2(-38, -40), p + Vector2(38, -40), p + Vector2(38, 2),
				p + Vector2(0, 46), p + Vector2(-38, 2)])
			draw_colored_polygon(pts, Color(0.16, 0.24, 0.55))
			draw_polyline(pts + PackedVector2Array([pts[0]]), light, 5.0, true)
			draw_line(p + Vector2(0, -36), p + Vector2(0, 40), c, 4.0)
			draw_line(p + Vector2(-34, -6), p + Vector2(34, -6), c, 4.0)
			var cr := PackedVector2Array([p + Vector2(-26, -50), p + Vector2(-26, -66), p + Vector2(-13, -56),
				p + Vector2(0, -72), p + Vector2(13, -56), p + Vector2(26, -66), p + Vector2(26, -50)])
			draw_colored_polygon(cr, c)
			draw_polyline(cr + PackedVector2Array([cr[0]]), ink, 2.0, true)
		"snowflake":
			for i in 6:
				var a := TAU * i / 6.0 + _time * 0.3
				var d := Vector2(cos(a), sin(a))
				draw_line(p, p + d * 52.0, light, 6.0, true)
				for k in [22.0, 38.0]:
					var b: Vector2 = p + d * k
					draw_line(b, b + d.rotated(0.8) * 14.0, light, 4.0, true)
					draw_line(b, b + d.rotated(-0.8) * 14.0, light, 4.0, true)
			draw_circle(p, 10.0, Color.WHITE)
		"boulder":  # a rock with motion lines
			var rock := PackedVector2Array()
			for i in 9:
				var a := TAU * i / 9.0
				rock.append(p + Vector2(10, 0) + Vector2(cos(a), sin(a)) * (34.0 + (8.0 if i % 2 == 0 else 0.0)))
			draw_colored_polygon(rock, Color(0.45, 0.42, 0.40))
			draw_polyline(rock + PackedVector2Array([rock[0]]), ink, 3.0, true)
			draw_line(p + Vector2(0, -8), p + Vector2(16, 6), Color(0.3, 0.28, 0.27), 3.0)
			for i in 3:
				var y := -20.0 + i * 20.0
				draw_line(p + Vector2(-62, y), p + Vector2(-34, y), light, 5.0, true)
		"swirl":  # two arrows chasing each other (teleport swap)
			draw_arc(p, 40.0, -0.3 + _time, PI - 0.5 + _time, 24, light, 7.0, true)
			draw_arc(p, 40.0, PI - 0.3 + _time, TAU - 0.5 + _time, 24, c, 7.0, true)
			for k in [0.0, PI]:
				var a: float = PI - 0.5 + _time + k
				var tip := p + Vector2(cos(a), sin(a)) * 40.0
				var d := Vector2(-sin(a), cos(a))
				draw_colored_polygon(PackedVector2Array([tip + d * 14.0, tip + d.rotated(PI / 2) * 10.0, tip - d.rotated(PI / 2) * 10.0]),
					light if k == 0.0 else c)
			draw_circle(p, 12.0, Color(1, 1, 1, 0.8))
		"flame":
			var f := 1.0 + 0.06 * sin(_time * 9.0)
			var outer := PackedVector2Array([p + Vector2(0, -58) * f, p + Vector2(22, -24), p + Vector2(34, 6), p + Vector2(26, 34),
				p + Vector2(0, 46), p + Vector2(-26, 34), p + Vector2(-34, 6), p + Vector2(-14, -18), p + Vector2(-8, -36)])
			draw_colored_polygon(outer, Color(0.95, 0.30, 0.08))
			var inner := PackedVector2Array([p + Vector2(0, -26) * f, p + Vector2(16, 4), p + Vector2(14, 28),
				p + Vector2(0, 36), p + Vector2(-14, 28), p + Vector2(-16, 6)])
			draw_colored_polygon(inner, Color(1.0, 0.8, 0.25))
			draw_polyline(outer + PackedVector2Array([outer[0]]), ink, 2.5, true)
		"wall":  # three overlapping shields
			for i in 3:
				var c2 := p + Vector2(-34 + i * 34, 6 - (8 if i == 1 else 0))
				var sh := PackedVector2Array([c2 + Vector2(-20, -26), c2 + Vector2(20, -26), c2 + Vector2(20, 4),
					c2 + Vector2(0, 30), c2 + Vector2(-20, 4)])
				draw_colored_polygon(sh, Color(0.55, 0.38, 0.15) if i != 1 else c)
				draw_polyline(sh + PackedVector2Array([sh[0]]), ink, 2.5, true)
				draw_line(c2 + Vector2(0, -22), c2 + Vector2(0, 24), light, 3.0)
		"crystal":  # a glowing crystal cluster with a pickaxe
			for k in [[-26.0, 30.0, 0.9], [0.0, 46.0, 1.0], [24.0, 34.0, 0.85]]:
				var base := p + Vector2(k[0], 36)
				var h: float = k[1] * (1.0 + 0.05 * sin(_time * 3.0 + k[0]))
				var cr := PackedVector2Array([base + Vector2(-12, 0), base + Vector2(-9, -h * 0.8), base + Vector2(0, -h - 14),
					base + Vector2(9, -h * 0.8), base + Vector2(12, 0)])
				draw_colored_polygon(cr, Color(c.r, c.g, c.b, k[2]))
				draw_polyline(cr + PackedVector2Array([cr[0]]), light, 2.0, true)
			draw_line(p + Vector2(-56, -40), p + Vector2(-20, 4), Color(0.5, 0.33, 0.18), 6.0, true)
			draw_arc(p + Vector2(-52, -44), 18.0, -0.4, 2.0, 12, Color(0.75, 0.77, 0.82), 5.0, true)
		"spear":  # a spear thrusting forward with chevrons
			draw_line(p + Vector2(-50, 40), p + Vector2(30, -40), Color(0.5, 0.33, 0.18), 7.0, true)
			var tip := PackedVector2Array([p + Vector2(48, -58), p + Vector2(22, -46), p + Vector2(36, -32)])
			draw_colored_polygon(tip, Color(0.85, 0.87, 0.92))
			draw_polyline(tip + PackedVector2Array([tip[0]]), ink, 2.0, true)
			for i in 3:
				var o := Vector2(-14, 14) * i + p + Vector2(-12, 30)
				draw_polyline(PackedVector2Array([o + Vector2(-10, -16), o, o + Vector2(16, 10)]), c, 5.0, true)
