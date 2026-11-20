class_name BattleCard
extends Control
## One card of the battle deck: a picture of the hero (or a drawn spell),
## its energy cost, its name and whether it can be played now.

signal pressed(idx: int)

const W := 96.0
const H := 128.0

var idx := 0
var card_id := ""
var cost := 0
var key_hint := ""
var wait := 0.0          ## seconds until ready, -1 = hero on the field
var affordable := true
var chosen := false
var _hover := false
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true)
	mouse_exited.connect(func(): _hover = false)


func setup(p_idx: int, id: String) -> void:
	idx = p_idx
	card_id = id
	cost = int(BattleData.card(id).get("cost", 0))
	key_hint = str(p_idx + 1)
	tooltip_text = "%s\n%s" % [HeroTexts.name_of(id), HeroTexts.role_of(id)]


func set_state(p_wait: float, p_affordable: bool, p_chosen: bool) -> void:
	if absf(p_wait - wait) > 0.05 or p_affordable != affordable or p_chosen != chosen:
		wait = p_wait
		affordable = p_affordable
		chosen = p_chosen
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if chosen or _hover:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(idx)
		accept_event()


func ready_now() -> bool:
	return wait == 0.0 and affordable


func _draw() -> void:
	var lift := -6.0 if (_hover or chosen) and ready_now() else 0.0
	var r := Rect2(Vector2(2, 2 + lift), Vector2(W - 4, H - 4))
	var spell := BattleData.is_spell(card_id)
	var frame := Color(0.75, 0.56, 0.26) if not spell else Color(0.55, 0.42, 0.85)
	if chosen:
		frame = Color(1.0, 0.95, 0.6).lerp(frame, 0.5 + 0.5 * sin(_time * 8.0))
	draw_style_box(_box(Color(0.10, 0.09, 0.11), frame, 3, 8), r)
	var art := Rect2(r.position + Vector2(5, 5), Vector2(r.size.x - 10, r.size.y - 36))
	draw_style_box(_box(Color(0.20, 0.24, 0.30) if not spell else Color(0.16, 0.10, 0.24), Color(0, 0, 0, 0), 0, 5), art)
	var tex := Portraits.get_tex(card_id, 0)
	if tex != null:
		draw_texture_rect(tex, art, false)
	elif spell:
		_spell_icon(card_id, art.get_center(), art.size.x * 0.32)
	var font := UiKit.font(700)
	var name := HeroTexts.name_of(card_id)
	draw_string_outline(font, Vector2(r.position.x, r.end.y - 12), name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, 4, Color(0, 0, 0))
	draw_string(font, Vector2(r.position.x, r.end.y - 12), name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, UiKit.TEXT)
	# energy gem
	var g := r.position + Vector2(14, 14)
	var gem := PackedVector2Array([g + Vector2(0, -13), g + Vector2(12, 0), g + Vector2(0, 13), g + Vector2(-12, 0)])
	draw_colored_polygon(gem, Style.CRYSTAL.darkened(0.25))
	draw_polyline(gem + PackedVector2Array([gem[0]]), Color(0.85, 1, 1), 2.0, true)
	draw_string_outline(font, g + Vector2(-12, 6), str(cost), HORIZONTAL_ALIGNMENT_CENTER, 24, 17, 4, Color(0, 0, 0))
	draw_string(font, g + Vector2(-12, 6), str(cost), HORIZONTAL_ALIGNMENT_CENTER, 24, 17, Color.WHITE)
	draw_string_outline(font, r.position + Vector2(r.size.x - 18, 16), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, 3, Color(0, 0, 0))
	draw_string(font, r.position + Vector2(r.size.x - 18, 16), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiKit.TEXT_SOFT)
	# not ready: dark cover with the reason
	if wait != 0.0 or not affordable:
		draw_style_box(_box(Color(0, 0, 0, 0.55), Color(0, 0, 0, 0), 0, 8), r)
		var msg := ""
		if wait < 0.0:
			msg = "בקרב"
		elif wait > 0.0:
			msg = str(ceili(wait))
		if msg != "":
			draw_string_outline(font, Vector2(r.position.x, r.get_center().y), msg, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, 6, Color(0, 0, 0))
			draw_string(font, Vector2(r.position.x, r.get_center().y), msg, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, UiKit.GOLD)


func _box(bg: Color, border: Color, bw: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	return s


## Simple drawn pictures for the spell cards.
func _spell_icon(id: String, p: Vector2, s: float) -> void:
	match id:
		"ice_bomb":
			draw_circle(p + Vector2(0, 4), s * 0.8, Color(0.55, 0.85, 1.0))
			for i in 6:
				var d := Vector2.from_angle(TAU * i / 6.0 + _time * 0.5)
				draw_line(p + Vector2(0, 4), p + Vector2(0, 4) + d * s * 0.7, Color.WHITE, 3.0, true)
			draw_line(p + Vector2(s * 0.4, -s * 0.5), p + Vector2(s * 0.7, -s * 0.95), Color(0.5, 0.35, 0.2), 4.0)
		"fire_bomb":
			draw_circle(p + Vector2(0, 6), s * 0.8, Color(0.15, 0.12, 0.12))
			draw_circle(p + Vector2(-s * 0.25, -s * 0.1), s * 0.18, Color(0.5, 0.5, 0.55))
			draw_line(p + Vector2(s * 0.4, -s * 0.4), p + Vector2(s * 0.7, -s * 0.85), Color(0.6, 0.45, 0.25), 4.0)
			draw_circle(p + Vector2(s * 0.75, -s * 0.95), s * 0.18 + sin(_time * 12.0) * 2.0, Color(1.0, 0.6, 0.1))
		"heal_potion":
			draw_circle(p + Vector2(0, s * 0.25), s * 0.7, Color(0.85, 0.2, 0.3))
			draw_rect(Rect2(p + Vector2(-s * 0.2, -s * 0.85), Vector2(s * 0.4, s * 0.6)), Color(0.85, 0.85, 0.9))
			draw_rect(Rect2(p + Vector2(-s * 0.25, -s * 1.0), Vector2(s * 0.5, s * 0.2)), Color(0.55, 0.35, 0.2))
			draw_rect(Rect2(p + Vector2(-s * 0.08, 0), Vector2(s * 0.16, s * 0.5)), Color.WHITE)
			draw_rect(Rect2(p + Vector2(-s * 0.25, s * 0.17), Vector2(s * 0.5, s * 0.16)), Color.WHITE)
		"shield_wall":
			for i in 3:
				var c := p + Vector2((i - 1) * s * 0.65, 0)
				var pts := PackedVector2Array([c + Vector2(-s * 0.32, -s * 0.5), c + Vector2(s * 0.32, -s * 0.5), c + Vector2(s * 0.32, s * 0.1), c + Vector2(0, s * 0.6), c + Vector2(-s * 0.32, s * 0.1)])
				draw_colored_polygon(pts, Color(0.75, 0.6, 0.3))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.2, 0.12, 0.05), 2.0, true)
