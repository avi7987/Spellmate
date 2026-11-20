class_name BattleCard
extends Control
## One card of the deck, mobile-game style: a rounded card with a coloured
## frame (blue = cheap, orange = medium, purple = expensive, green = spell),
## a picture of the hero (or a drawn spell), the energy cost in a pink drop,
## the name in white outlined letters. Shows if it is planned, recharging or
## too expensive.

signal pressed(idx: int)

const W := 92.0
const H := 128.0

var idx := 0
var card_id := ""
var cost := 0
var key_hint := ""
var wait := 0.0          ## seconds until ready
var affordable := true
var chosen := false      ## planned this turn / being aimed
var turn_seconds := 0.0  ## > 0: show waits in turns
var chosen_text := "✔ מתוכנן"
var _hover := false
var _time := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


func setup(p_idx: int, id: String) -> void:
	idx = p_idx
	card_id = id
	cost = int(BattleData.card(id).get("cost", 0))
	key_hint = str(p_idx + 1)
	tooltip_text = "%s (%d אנרגיה)\n%s" % [HeroTexts.name_of(id), cost, HeroTexts.role_of(id)]


func set_state(p_wait: float, p_affordable: bool, p_chosen: bool, p_turn_seconds: float = 0.0) -> void:
	turn_seconds = p_turn_seconds
	if absf(p_wait - wait) > 0.05 or p_affordable != affordable or p_chosen != chosen:
		wait = p_wait
		affordable = p_affordable
		chosen = p_chosen
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	if chosen:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(idx)
		accept_event()


func ready_now() -> bool:
	return wait == 0.0 and affordable


func rarity_color() -> Color:
	if BattleData.is_spell(card_id):
		return Color(0.35, 0.8, 0.35)
	if cost >= 6:
		return Color(0.7, 0.35, 0.95)
	if cost >= 4:
		return Color(1.0, 0.6, 0.15)
	return Color(0.35, 0.6, 1.0)


func _draw() -> void:
	var lift := -7.0 if (_hover or chosen) and (ready_now() or chosen) else 0.0
	var r := Rect2(Vector2(2, 3 + lift), Vector2(W - 4, H - 6))
	var frame := rarity_color()
	if chosen:
		frame = Color(0.4, 1.0, 0.4).lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 6.0))
	draw_style_box(UiKit.frame_style(UiKit.PANEL_EDGE, 3, frame), r)
	# picture window
	var art := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, r.size.y - 34))
	var bg := StyleBoxFlat.new()
	bg.bg_color = frame.darkened(0.55)
	bg.set_corner_radius_all(9)
	draw_style_box(bg, art)
	var tex := Portraits.get_tex(card_id, 0)
	if tex != null:
		draw_texture_rect(tex, art, false)
	elif BattleData.is_spell(card_id):
		_spell_icon(card_id, art.get_center(), art.size.x * 0.32)
	# name
	var name := HeroTexts.name_of(card_id)
	UiKit.draw_text_outlined(self, Vector2(r.position.x + 2, r.end.y - 9), name, r.size.x - 4, 16 if name.length() <= 7 else 13, Color.WHITE, 5)
	# cost drop (pink, like an elixir drop)
	var g := r.position + Vector2(13, 13)
	draw_circle(g, 14.0, UiKit.PANEL_EDGE)
	draw_circle(g, 11.5, Color(0.95, 0.3, 0.75))
	draw_circle(g + Vector2(-3, -4), 4.0, Color(1, 1, 1, 0.45))
	UiKit.draw_text_outlined(self, g + Vector2(-14, 7), str(cost), 28, 19, Color.WHITE, 5)
	if key_hint != "":
		UiKit.draw_text_outlined(self, r.position + Vector2(r.size.x - 22, 19), key_hint, 18, 14, UiKit.TEXT_SOFT, 4)
	if chosen:
		_ribbon(r, chosen_text, Color(0.2, 0.6, 0.2))
		return
	if wait != 0.0 or not affordable:
		draw_style_box(_dark(), r)
		var msg := ""
		if wait > 0.0:
			msg = ("עוד %d תורות" % ceili(wait / turn_seconds) if ceili(wait / turn_seconds) > 1 else "בתור הבא") if turn_seconds > 0.0 else str(ceili(wait))
		elif not affordable:
			msg = "חסרה אנרגיה"
		if msg != "":
			_ribbon(r, msg, Color(0.75, 0.2, 0.15))


func _dark() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0.5)
	s.set_corner_radius_all(14)
	return s


## A ribbon across the card with a short word.
func _ribbon(r: Rect2, msg: String, col: Color) -> void:
	var y := r.position.y + r.size.y * 0.44
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = UiKit.PANEL_EDGE
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(6)
	draw_style_box(sb, Rect2(r.position.x - 3, y - 14, r.size.x + 6, 28))
	UiKit.draw_text_outlined(self, Vector2(r.position.x, y + 6), msg, r.size.x, 14, Color.WHITE, 4)


## Simple drawn pictures for the spell cards.
func _spell_icon(id: String, p: Vector2, s: float) -> void:
	match id:
		"ice_bomb":
			draw_circle(p + Vector2(0, 4), s * 0.8, Color(0.55, 0.85, 1.0))
			for i in 6:
				var d := Vector2.from_angle(TAU * i / 6.0)
				draw_line(p + Vector2(0, 4), p + Vector2(0, 4) + d * s * 0.7, Color.WHITE, 3.0, true)
			draw_line(p + Vector2(s * 0.4, -s * 0.5), p + Vector2(s * 0.7, -s * 0.95), Color(0.5, 0.35, 0.2), 4.0)
		"fire_bomb":
			draw_circle(p + Vector2(0, 6), s * 0.8, Color(0.15, 0.12, 0.12))
			draw_circle(p + Vector2(-s * 0.25, -s * 0.1), s * 0.18, Color(0.5, 0.5, 0.55))
			draw_line(p + Vector2(s * 0.4, -s * 0.4), p + Vector2(s * 0.7, -s * 0.85), Color(0.6, 0.45, 0.25), 4.0)
			draw_circle(p + Vector2(s * 0.75, -s * 0.95), s * 0.2, Color(1.0, 0.6, 0.1))
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
