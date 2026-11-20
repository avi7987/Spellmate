class_name BattleCard
extends Control
## One card of the deck, like a page of an illuminated manuscript: parchment,
## a gold frame, a picture of the hero (or a drawn spell), the energy cost in a
## crystal, the name in ink. Shows if it is planned, waiting or too expensive.

signal pressed(idx: int)

const W := 92.0
const H := 128.0

var idx := 0
var card_id := ""
var cost := 0
var key_hint := ""
var wait := 0.0          ## seconds until ready, -1 = hero on the field
var affordable := true
var chosen := false      ## planned this turn / being aimed
var turn_seconds := 0.0  ## > 0: show waits in turns
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
	tooltip_text = "%s  (◆%d)\n%s" % [HeroTexts.name_of(id), cost, HeroTexts.role_of(id)]


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


func _draw() -> void:
	var lift := -7.0 if (_hover or chosen) and (ready_now() or chosen) else 0.0
	var r := Rect2(Vector2(2, 3 + lift), Vector2(W - 4, H - 6))
	var spell := BattleData.is_spell(card_id)
	# parchment body
	var sb := StyleBoxTexture.new()
	sb.texture = UiKit.TEX_PAPER
	sb.set_texture_margin_all(16)
	draw_style_box(sb, r)
	var gold := UiKit.GOLD_DARK
	if chosen:
		gold = Color(0.2, 0.55, 0.15).lerp(UiKit.GOLD, 0.5 + 0.5 * sin(_time * 6.0))
	draw_rect(r.grow(-1), gold, false, 3.0)
	# picture window
	var art := Rect2(r.position + Vector2(7, 7), Vector2(r.size.x - 14, r.size.y - 40))
	var bg := Color(0.30, 0.20, 0.36) if spell else Color(0.36, 0.30, 0.22)
	draw_rect(art, bg)
	var tex := Portraits.get_tex(card_id, 0)
	if tex != null:
		draw_texture_rect(tex, art, false)
	elif spell:
		_spell_icon(card_id, art.get_center(), art.size.x * 0.32)
	draw_rect(art, UiKit.INK, false, 2.0)
	# name in ink
	var name := HeroTexts.name_of(card_id)
	var fs := 16 if name.length() <= 8 else 13
	draw_string(UiKit.FONT_BOLD, Vector2(r.position.x, r.end.y - 11), name, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, UiKit.INK)
	# cost crystal
	var g := r.position + Vector2(14, 15)
	var gem := PackedVector2Array([g + Vector2(0, -14), g + Vector2(12, 0), g + Vector2(0, 14), g + Vector2(-12, 0)])
	draw_colored_polygon(gem, Style.CRYSTAL.darkened(0.3))
	draw_polyline(gem + PackedVector2Array([gem[0]]), UiKit.INK, 2.0, true)
	draw_string_outline(UiKit.FONT_BOLD, g + Vector2(-12, 6), str(cost), HORIZONTAL_ALIGNMENT_CENTER, 24, 18, 4, UiKit.OUTLINE)
	draw_string(UiKit.FONT_BOLD, g + Vector2(-12, 6), str(cost), HORIZONTAL_ALIGNMENT_CENTER, 24, 18, Color.WHITE)
	if key_hint != "":
		draw_string(UiKit.FONT_BOLD, r.position + Vector2(r.size.x - 18, 19), key_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UiKit.INK_SOFT)
	if chosen:
		_ribbon(r, "✔ מתוכנן", Color(0.18, 0.45, 0.12))
		return
	if wait != 0.0 or not affordable:
		draw_rect(r, Color(0.15, 0.08, 0.02, 0.5))
		var msg := ""
		if wait < 0.0:
			msg = "בקרב"
		elif wait > 0.0:
			msg = ("עוד %d תורות" % ceili(wait / turn_seconds)) if turn_seconds > 0.0 else str(ceili(wait))
		elif not affordable:
			msg = "חסר ◆"
		if msg != "":
			_ribbon(r, msg, UiKit.RED_INK)


## A ribbon across the card with a short word.
func _ribbon(r: Rect2, msg: String, col: Color) -> void:
	var y := r.position.y + r.size.y * 0.44
	draw_rect(Rect2(r.position.x - 2, y - 13, r.size.x + 4, 26), col)
	draw_line(Vector2(r.position.x - 2, y - 13), Vector2(r.end.x + 2, y - 13), UiKit.GOLD, 1.5)
	draw_line(Vector2(r.position.x - 2, y + 13), Vector2(r.end.x + 2, y + 13), UiKit.GOLD, 1.5)
	draw_string(UiKit.FONT_BOLD, Vector2(r.position.x, y + 6), msg, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, UiKit.CREAM)


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
