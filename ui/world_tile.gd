class_name WorldTile
extends Control
## A clickable picture of a world for the world picker: a little drawn
## landscape in the world's colours (ground, special ground, water, trees),
## its name, and what is special about it.

signal pressed

const W := 225.0
const H := 210.0

var id := ""
var world: Dictionary = {}
var chosen := false
var _hover := false


func _init() -> void:
	custom_minimum_size = Vector2(W, H)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(func(): _hover = true; queue_redraw())
	mouse_exited.connect(func(): _hover = false; queue_redraw())


func setup(p_id: String, p_world: Dictionary, p_chosen: bool) -> void:
	id = p_id
	world = p_world
	chosen = p_chosen
	tooltip_text = world.get("desc", "")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()


func _c(key: String) -> Color:
	return Color.html(world.get("colors", {}).get(key, "#808080"))


func _draw() -> void:
	var lift := -5.0 if _hover or chosen else 0.0
	var r := Rect2(Vector2(4, 4 + lift), Vector2(W - 8, H - 10))
	var frame := UiKit.frame_style(UiKit.GOLD if chosen else UiKit.PANEL_EDGE, 5 if chosen else 3)
	draw_style_box(frame, r)
	# a tiny landscape: sky, ground, special patches, a river, trees
	var pic := Rect2(r.position + Vector2(10, 10), Vector2(r.size.x - 20, 108))
	draw_rect(Rect2(pic.position, Vector2(pic.size.x, 34)), _c("sky"))
	draw_rect(Rect2(pic.position + Vector2(0, 34), Vector2(pic.size.x, pic.size.y - 34)), _c("plain"))
	draw_rect(Rect2(pic.position + Vector2(0, 66), Vector2(pic.size.x, 14)), _c("water"))
	for p in [Vector2(20, 44), Vector2(140, 88), Vector2(90, 50)]:
		draw_rect(Rect2(pic.position + p, Vector2(38, 14)), _c("special"))
	for x in [30.0, 70.0, 160.0, 180.0]:
		var base := pic.position + Vector2(x, 60 if x < 100 else 100)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-9, 0), base + Vector2(9, 0), base + Vector2(0, -22)]), _c("forest").darkened(0.2))
	draw_rect(pic, UiKit.OUTLINE, false, 2.0)
	var name: String = world.get("name", id)
	UiKit.draw_text_outlined(self, Vector2(r.position.x, pic.end.y + 30), name, r.size.x, 23, Color.WHITE if not chosen else UiKit.GOLD)
	var rule: String = world.get("special", {}).get("name", "")
	var desc: String = _rule_text()
	UiKit.draw_text_outlined(self, Vector2(r.position.x, pic.end.y + 56), desc, r.size.x, 16, UiKit.TEXT_SOFT, 3)
	if chosen:
		UiKit.draw_text_outlined(self, Vector2(r.position.x, r.position.y + 30), "✔ נבחר", r.size.x - 20, 18, UiKit.GOLD, 4)


func _rule_text() -> String:
	var sp: Dictionary = world.get("special", {})
	var n: String = sp.get("name", "")
	if sp.has("dps"):
		return "%s: שורפת" % n
	if sp.has("heal"):
		return "%s: מרפאים" % n
	if sp.get("effect", "") == "shield":
		return "%s: מגן" % n
	if sp.has("effect"):
		return "%s: זעם מתוק" % n
	var s := float(sp.get("speed", 1.0))
	if s < 0.95:
		return "%s: מאט" % n
	if s > 1.05:
		return "%s: מחליקים מהר" % n
	return "עולם רגיל"
