class_name BattleCard
extends Control
## One card of the deck: SHINY RARE CARDS in the royal style.
##   rarity (data "rarity"): common = silver, rare = sapphire, epic = amethyst,
##   legendary = gold with a rainbow shimmer. Rare and better cards have a
##   holographic band of light that sweeps over them; epic and legendary ones
##   sparkle. The energy cost sits in a blue crystal, the name on a red ribbon,
##   and a small gem at the bottom shows the rarity. The card grows a little
##   under the mouse. It also shows if it is planned, recharging or too expensive.

signal pressed(idx: int)

const W := 108.0
const H := 150.0
const RARITY := {
	"common": [Color(0.72, 0.74, 0.80), "רגיל"],
	"rare": [Color(0.25, 0.55, 1.0), "נדיר"],
	"epic": [Color(0.72, 0.35, 1.0), "אפי"],
	"legendary": [Color(1.0, 0.78, 0.22), "אגדי"],
}

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
var _time := randf() * 10.0
var rarity := "common"
var grow_on_hover := true


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true; _grow(true))
	mouse_exited.connect(func(): _hover = false; _grow(false))


func _grow(on: bool) -> void:
	queue_redraw()
	if not grow_on_hover:
		return
	pivot_offset = Vector2(W / 2.0, H)
	z_index = 5 if on else 0
	create_tween().tween_property(self, "scale", Vector2.ONE * (1.14 if on else 1.0), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func setup(p_idx: int, id: String) -> void:
	idx = p_idx
	card_id = id
	cost = int(BattleData.card(id).get("cost", 0))
	rarity = String(BattleData.card(id).get("rarity", "common"))
	key_hint = str(p_idx + 1)
	tooltip_text = "%s · %s (%d אנרגיה)\n%s" % [HeroTexts.name_of(id), RARITY.get(rarity, RARITY["common"])[1], cost, HeroTexts.role_of(id)]


func set_state(p_wait: float, p_affordable: bool, p_chosen: bool, p_turn_seconds: float = 0.0) -> void:
	turn_seconds = p_turn_seconds
	if absf(p_wait - wait) > 0.05 or p_affordable != affordable or p_chosen != chosen:
		wait = p_wait
		affordable = p_affordable
		chosen = p_chosen
		queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	# rare cards shine all the time
	if chosen or rarity != "common" or _hover:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(idx)
		accept_event()


func ready_now() -> bool:
	return wait == 0.0 and affordable


func rarity_color() -> Color:
	return RARITY.get(rarity, RARITY["common"])[0]


func _draw() -> void:
	var r := Rect2(Vector2(2, 3), Vector2(W - 4, H - 6))
	var frame := rarity_color()
	if rarity == "legendary":
		# a slow rainbow shimmer in the gold
		frame = frame.lerp(Color.from_hsv(fmod(_time * 0.15, 1.0), 0.45, 1.0), 0.25)
	if chosen:
		frame = Color(0.4, 1.0, 0.4).lerp(Color.WHITE, 0.5 + 0.5 * sin(_time * 6.0))
	# the outer glow of rare cards
	if rarity != "common" and not chosen:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color(0, 0, 0, 0)
		glow.shadow_color = Color(frame.r, frame.g, frame.b, 0.35 + 0.15 * sin(_time * 2.5))
		glow.shadow_size = 9 if rarity == "legendary" else 6
		glow.set_corner_radius_all(14)
		draw_style_box(glow, r)
	# body: a metal frame in the rarity colour with a dark rim and an inner gold line
	draw_style_box(UiKit.frame_style(UiKit.PANEL_EDGE, 3, frame), r)
	var inner := StyleBoxFlat.new()
	inner.bg_color = frame.darkened(0.2)
	inner.border_color = Color(1, 0.9, 0.6, 0.8) if rarity in ["epic", "legendary"] else frame.lightened(0.35)
	inner.set_border_width_all(2)
	inner.set_corner_radius_all(11)
	draw_style_box(inner, r.grow(-4))
	# picture window
	var art := Rect2(r.position + Vector2(8, 8), Vector2(r.size.x - 16, r.size.y - 44))
	var bg := StyleBoxFlat.new()
	bg.bg_color = frame.darkened(0.6)
	bg.set_corner_radius_all(8)
	bg.border_color = UiKit.PANEL_EDGE
	bg.set_border_width_all(2)
	draw_style_box(bg, art)
	# soft light rays behind the hero
	var center := art.get_center() + Vector2(0, -4)
	for k in 8:
		var a := TAU * k / 8.0 + _time * 0.3
		var pts := PackedVector2Array([center, center + Vector2.from_angle(a - 0.12) * art.size.x, center + Vector2.from_angle(a + 0.12) * art.size.x])
		var clip := Geometry2D.intersect_polygons(pts, _rect_poly(art.grow(-2)))
		for poly in clip:
			draw_colored_polygon(poly, Color(frame.r, frame.g, frame.b, 0.12))
	var tex := Portraits.get_tex(card_id, 0)
	if tex != null:
		draw_texture_rect(tex, art, false)
	elif BattleData.is_spell(card_id):
		_spell_icon(card_id, art.get_center(), art.size.x * 0.3)
	# the holographic band of light (rare and better)
	if rarity != "common":
		var speed: float = {"rare": 0.35, "epic": 0.5, "legendary": 0.7}[rarity]
		var t := fmod(_time * speed, 1.6) - 0.3
		var x := r.position.x + t * r.size.x * 1.4
		var band := PackedVector2Array([Vector2(x, r.position.y), Vector2(x + 18, r.position.y), Vector2(x - 22, r.end.y), Vector2(x - 40, r.end.y)])
		var col := Color(1, 1, 1, 0.28)
		if rarity == "legendary":
			col = Color.from_hsv(fmod(_time * 0.4, 1.0), 0.5, 1.0, 0.35)
		for poly in Geometry2D.intersect_polygons(band, _rect_poly(r.grow(-4))):
			draw_colored_polygon(poly, col)
	# sparkles (epic and legendary)
	if rarity in ["epic", "legendary"]:
		for k in (5 if rarity == "legendary" else 3):
			var ph := _time * 1.3 + k * 1.7
			var tw := maxf(0.0, sin(ph * 2.0))
			if tw <= 0.05:
				continue
			var sp := art.position + Vector2(fmod(k * 37.0 + floor(ph / PI) * 23.0, art.size.x), fmod(k * 53.0 + floor(ph / PI) * 41.0, art.size.y))
			var sz := 5.0 * tw
			draw_line(sp - Vector2(sz, 0), sp + Vector2(sz, 0), Color(1, 1, 0.9, tw), 2.0, true)
			draw_line(sp - Vector2(0, sz), sp + Vector2(0, sz), Color(1, 1, 0.9, tw), 2.0, true)
	# the name on a red velvet ribbon with gold edges
	var name := HeroTexts.name_of(card_id)
	var rib := Rect2(r.position.x + 1, r.end.y - 34, r.size.x - 2, 24)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = UiKit.PANEL_BG
	rsb.border_color = UiKit.GOLD_RIM
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(5)
	draw_style_box(rsb, rib)
	UiKit.draw_text_outlined(self, Vector2(rib.position.x, rib.end.y - 6), name, rib.size.x, 15 if name.length() <= 8 else 12, Color.WHITE, 4)
	# the rarity gem under the ribbon
	var gp := Vector2(r.get_center().x, r.end.y - 5)
	var gem := PackedVector2Array([gp + Vector2(0, -6), gp + Vector2(6, 0), gp + Vector2(0, 6), gp + Vector2(-6, 0)])
	draw_colored_polygon(gem, rarity_color().lightened(0.2))
	draw_polyline(gem + PackedVector2Array([gem[0]]), UiKit.PANEL_EDGE, 1.5, true)
	# the cost: a blue energy crystal
	var g := r.position + Vector2(15, 17)
	var crystal := PackedVector2Array([g + Vector2(0, -16), g + Vector2(13, -5), g + Vector2(9, 13), g + Vector2(-9, 13), g + Vector2(-13, -5)])
	draw_colored_polygon(crystal, Style.CRYSTAL.darkened(0.15))
	draw_colored_polygon(PackedVector2Array([g + Vector2(0, -16), g + Vector2(13, -5), g + Vector2(0, -1), g + Vector2(-13, -5)]), Style.CRYSTAL.lightened(0.35))
	draw_polyline(crystal + PackedVector2Array([crystal[0]]), UiKit.PANEL_EDGE, 2.5, true)
	UiKit.draw_text_outlined(self, g + Vector2(-15, 10), str(cost), 30, 19, Color.WHITE, 5)
	if key_hint != "":
		UiKit.draw_text_outlined(self, r.position + Vector2(r.size.x - 24, 20), key_hint, 18, 14, UiKit.TEXT_SOFT, 4)
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


func _rect_poly(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])


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
