class_name ResultsPanel
extends Control
## After a battle: victory or defeat, the rewards (gold, trophies, hero XP,
## a chest) and a button back to the base.

signal closed


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	theme = UiKit.make_theme()


func show_results(result: Dictionary, rewards: Dictionary, profile: Profile) -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var won: bool = result.get("won", false)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var p := UiKit.panel(UiKit.GOLD if won else Color(1, 0.4, 0.3))
	p.custom_minimum_size = Vector2(600, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var title := "ניצחון!" if won else ("תיקו" if result.get("draw", false) else ("ברחת מהקרב" if result.get("quit", false) else "הפסד…"))
	v.add_child(UiKit.title(title, 54, UiKit.GOLD if won else Color(1, 0.55, 0.45)))
	var m := int(result.get("time", 0))
	v.add_child(UiKit.label("זמן קרב %d:%02d · אויבים שהופלו %d · מבנים שנשברו %d" % [m / 60, m % 60, int(result.get("kills", 0)), int(result.get("structures", 0))], 17, UiKit.TEXT_SOFT))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 6)
	grid.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(grid)
	var rows := [
		["🪙 זהב", "+%d" % int(rewards.get("gold", 0)), UiKit.GOLD],
		["🏆 גביעים", "%+d  (סה״כ %d)" % [int(rewards.get("trophies", 0)), profile.trophies], Color(1, 0.85, 0.5)],
		["⭐ ניסיון לכל גיבור בחפיסה", "+%d" % int(rewards.get("xp", 0)), Color(0.6, 0.9, 1.0)],
	]
	for r in rows:
		var a := UiKit.label(r[0], 22, UiKit.TEXT, 700)
		a.autowrap_mode = TextServer.AUTOWRAP_OFF
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(a)
		var b := UiKit.label(r[1], 24, r[2], 800)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.modulate.a = 0.0
		grid.add_child(b)
		b.create_tween().tween_property(b, "modulate:a", 1.0, 0.4).set_delay(0.3 + rows.find(r) * 0.35)
	if rewards.get("chest", "") != "":
		v.add_child(UiKit.label("קיבלת תיבת %s! פתח אותה בבסיס" % ChestNames.name_of(rewards["chest"]), 22, Color(1, 0.8, 0.4), 800))
	if rewards.get("new_arena", false):
		v.add_child(UiKit.title("עלית לזירה חדשה: %s!" % profile.arena()["name"], 30))
	var b := UiKit.button("חזרה לבסיס", UiKit.BUTTON_BRONZE, 26)
	b.pressed.connect(func():
		Sfx.play("click")
		closed.emit())
	v.add_child(b)
	await get_tree().process_frame
	p.pivot_offset = p.size / 2
	p.scale = Vector2(0.7, 0.7)
	p.create_tween().tween_property(p, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if rewards.get("gold", 0) > 0:
		Sfx.play("reward")
