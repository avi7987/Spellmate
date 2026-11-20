class_name BattleHud
extends CanvasLayer
## The screen of a real-time battle (all built in code):
##   top:    the two kingdoms' palace health, the clock, pause and exit buttons
##   bottom: energy, the 8 deck cards, palace upgrade, powers of the selected heroes
##   middle: short messages and hints

signal card_pressed(idx: int)
signal ability_pressed(unit_id: int)
signal upgrade_pressed
signal pause_pressed
signal exit_pressed

var battle: Battle
var viewer := 0
var cards: Array = []
var _root: Control
var _energy_label: Label
var _energy_bar: Control
var _clock: Label
var _pause_label: Label
var _hint: Label
var _flash: Label
var _abilities: HBoxContainer
var _ability_ids: Array = []
var _upgrade: Button
var _team_bars: Array = []
var _drag_box: Panel
var _speech_root: Control


func setup(b: Battle, p_viewer: int) -> void:
	battle = b
	viewer = p_viewer
	for c in get_children():
		c.queue_free()
	cards.clear()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.make_theme()
	add_child(_root)
	_speech_root = Control.new()
	_speech_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_speech_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_speech_root)
	_build_top()
	_build_bottom()
	_hint = UiKit.label("", 19, UiKit.TEXT)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-400, -186)
	_hint.size = Vector2(800, 30)
	_hint.add_theme_constant_override("outline_size", 6)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)
	_flash = UiKit.title("", 46)
	_flash.set_anchors_preset(Control.PRESET_CENTER)
	_flash.position = Vector2(-500, -150)
	_flash.size = Vector2(1000, 80)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_drag_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.5, 1.0, 0.6, 0.12)
	sb.border_color = Color(0.6, 1.0, 0.7, 0.9)
	sb.set_border_width_all(2)
	_drag_box.add_theme_stylebox_override("panel", sb)
	_drag_box.visible = false
	_drag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_drag_box)


func _build_top() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 12
	bar.offset_right = -12
	bar.offset_top = 8
	bar.add_theme_constant_override("separation", 12)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	for team in [viewer, 1 - viewer]:
		var p := UiKit.panel(Style.team(team)["ui"])
		p.add_theme_stylebox_override("panel", _small_panel(Style.team(team)["ui"]))
		p.custom_minimum_size = Vector2(250, 0)
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		p.add_child(v)
		v.add_child(UiKit.label("ממלכת השמש" if team == 0 else "ממלכת האופל", 17, Style.team(team)["ui"], 700))
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(220, 14)
		pb.max_value = 1.0
		pb.step = 0.001
		var fill := StyleBoxFlat.new()
		fill.bg_color = Style.team(team)["ui"]
		fill.set_corner_radius_all(4)
		var bg := StyleBoxFlat.new()
		bg.bg_color = Color(0, 0, 0, 0.6)
		bg.set_corner_radius_all(4)
		pb.add_theme_stylebox_override("fill", fill)
		pb.add_theme_stylebox_override("background", bg)
		v.add_child(pb)
		var info := UiKit.label("", 14, UiKit.TEXT_SOFT)
		v.add_child(info)
		_team_bars.append([team, pb, info])
		bar.add_child(p)
		if team == viewer:
			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_clock = UiKit.title("0:00", 34)
			mid.add_child(_clock)
			_pause_label = UiKit.label("⏸  הפסקה - אפשר לתת פקודות", 18, UiKit.GOLD, 700)
			_pause_label.visible = false
			mid.add_child(_pause_label)
			bar.add_child(mid)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6)
	var pause := UiKit.button("⏸", UiKit.BUTTON_STEEL, 22)
	pause.custom_minimum_size = Vector2(54, 50)
	pause.tooltip_text = "הפסקה (רווח)"
	pause.pressed.connect(func(): pause_pressed.emit())
	btns.add_child(pause)
	var ex := UiKit.button("יציאה", UiKit.BUTTON_RED, 18)
	ex.custom_minimum_size = Vector2(80, 50)
	ex.pressed.connect(func(): exit_pressed.emit())
	btns.add_child(ex)
	bar.add_child(btns)


func _small_panel(accent: Color) -> StyleBoxFlat:
	var sb := UiKit.panel_style(UiKit.PANEL_BG, accent.darkened(0.3))
	sb.set_content_margin_all(8)
	return sb


func _build_bottom() -> void:
	var holder := HBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -150
	holder.offset_bottom = -6
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 10)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	# energy
	var ep := PanelContainer.new()
	ep.add_theme_stylebox_override("panel", _small_panel(Style.CRYSTAL))
	var ev := VBoxContainer.new()
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	ep.add_child(ev)
	ev.add_child(UiKit.label("אנרגיה", 15, Style.CRYSTAL, 700))
	_energy_label = UiKit.title("5", 40, Style.CRYSTAL.lightened(0.3))
	ev.add_child(_energy_label)
	_energy_bar = Control.new()
	_energy_bar.custom_minimum_size = Vector2(110, 16)
	_energy_bar.draw.connect(_draw_energy)
	ev.add_child(_energy_bar)
	holder.add_child(ep)
	# cards
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", _small_panel(UiKit.GOLD))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	cp.add_child(row)
	for i in battle.cards[viewer].size():
		var c := BattleCard.new()
		c.setup(i, battle.cards[viewer][i]["id"])
		c.pressed.connect(func(idx): card_pressed.emit(idx))
		row.add_child(c)
		cards.append(c)
	holder.add_child(cp)
	# palace upgrade + powers
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.alignment = BoxContainer.ALIGNMENT_END
	_abilities = HBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 6)
	side.add_child(_abilities)
	_upgrade = UiKit.button("", UiKit.BUTTON_BRONZE, 17)
	_upgrade.custom_minimum_size = Vector2(170, 50)
	_upgrade.tooltip_text = "המגדלים יורים חזק יותר, השער והמגדלים מתחזקים ומתרפאים"
	_upgrade.pressed.connect(func(): upgrade_pressed.emit())
	side.add_child(_upgrade)
	holder.add_child(side)


func _draw_energy() -> void:
	var n := int(battle.energy_max)
	var e: float = battle.energy[viewer]
	var w := _energy_bar.size.x / n
	for i in n:
		var r := Rect2(Vector2(i * w + 1, 0), Vector2(w - 2, _energy_bar.size.y))
		var full := clampf(e - i, 0.0, 1.0)
		_energy_bar.draw_rect(r, Color(0.05, 0.08, 0.1))
		if full > 0.0:
			_energy_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * full, r.size.y)), Style.CRYSTAL)


## Called every frame by the battle screen.
func refresh(selected: Array, chosen_card: int, paused: bool) -> void:
	if battle == null:
		return
	var e: float = battle.energy[viewer]
	_energy_label.text = str(int(e))
	_energy_bar.queue_redraw()
	var left := maxf(0.0, battle.time_limit - battle.time)
	_clock.text = "%d:%02d" % [int(left) / 60, int(left) % 60]
	_clock.add_theme_color_override("font_color", Color(1, 0.4, 0.3) if left < 30 else UiKit.GOLD)
	_pause_label.visible = paused
	for i in cards.size():
		var c: BattleCard = cards[i]
		c.set_state(battle.card_wait(viewer, i), e >= battle.card_cost(c.card_id), i == chosen_card)
	var cost := battle.palace_upgrade_cost(viewer)
	if cost < 0:
		_upgrade.text = "ארמון בדרגה מרבית"
		_upgrade.disabled = true
	else:
		_upgrade.text = "שדרוג ארמון  ◆%d" % cost
		_upgrade.disabled = e < cost
	for t in _team_bars:
		var team: int = t[0]
		var gate := "נפל"
		var towers := 0
		var k := battle.king(team)
		for u: BUnit in battle.units:
			if u.team == team and u.kind == "gate":
				gate = "%d%%" % int(100 * u.hp / u.max_hp)
			if u.team == team and u.kind == "tower":
				towers += 1
		t[1].value = battle._score(team) / 4.0
		t[2].text = "שער %s · מגדלים %d/2 · מלך %d%%" % [gate, towers, int(100 * k.hp / k.max_hp) if k else 0]
	_refresh_abilities(selected)


func _refresh_abilities(selected: Array) -> void:
	var ids := []
	for id in selected:
		var u := battle.unit(id)
		if u != null and not battle.ability_of(u).is_empty():
			ids.append(id)
	ids = ids.slice(0, 6)
	if ids != _ability_ids:
		_ability_ids = ids
		for c in _abilities.get_children():
			c.queue_free()
		for id in ids:
			var u := battle.unit(id)
			var ab := battle.ability_of(u)
			var b := UiKit.button("", UiKit.BUTTON_PURPLE, 14)
			b.custom_minimum_size = Vector2(96, 62)
			b.icon = Portraits.get_tex(u.kind, 0)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 34)
			b.tooltip_text = "%s - %s\n%s" % [HeroTexts.name_of(u.kind), HeroTexts.ability_name(ab["id"]), HeroTexts.ability_desc(ab["id"])]
			b.pressed.connect(func(): ability_pressed.emit(id))
			b.set_meta("unit", id)
			_abilities.add_child(b)
	var energy: float = battle.energy[viewer]
	var n := 0
	for b in _abilities.get_children():
		var u := battle.unit(b.get_meta("unit"))
		if u == null:
			continue
		var ab := battle.ability_of(u)
		var wait := u.ability_ready_at - battle.time
		var key := "Q" if n == 0 else ""
		n += 1
		if wait > 0.0:
			b.text = "%s\n%d" % [HeroTexts.ability_name(ab["id"]), ceili(wait)]
			b.disabled = true
		else:
			b.text = "%s %s\n◆%d" % [HeroTexts.ability_name(ab["id"]), key, int(ab.get("cost", 0))]
			b.disabled = energy < float(ab.get("cost", 0))


func set_hint(text: String, seconds: float = 0.0) -> void:
	_hint.text = text
	_hint.modulate.a = 1.0
	if seconds > 0.0:
		var tw := _hint.create_tween()
		tw.tween_interval(seconds)
		tw.tween_property(_hint, "modulate:a", 0.0, 0.6)


func flash(text: String, color: Color = UiKit.GOLD, hold: float = 1.0) -> void:
	_flash.text = text
	_flash.add_theme_color_override("font_color", color)
	var tw := _flash.create_tween()
	_flash.modulate.a = 0.0
	_flash.scale = Vector2(0.8, 0.8)
	_flash.pivot_offset = _flash.size / 2
	tw.set_parallel(true)
	tw.tween_property(_flash, "modulate:a", 1.0, 0.2)
	tw.tween_property(_flash, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(_flash, "modulate:a", 0.0, 0.4).set_delay(hold)


func show_drag_box(rect: Rect2) -> void:
	_drag_box.visible = rect.size.length() > 6.0
	_drag_box.position = rect.position
	_drag_box.size = rect.size


func hide_drag_box() -> void:
	_drag_box.visible = false


## A comic speech bubble over a character for a moment.
func speech(screen_pos: Vector2, text: String) -> void:
	if text == "":
		return
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.98, 0.96, 0.9)
	sb.border_color = Color(0.1, 0.07, 0.05)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(12)
	sb.set_content_margin_all(8)
	p.add_theme_stylebox_override("panel", sb)
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", Color(0.12, 0.08, 0.05))
	l.add_theme_font_size_override("font_size", 16)
	l.add_theme_font_override("font", UiKit.font(700))
	l.add_theme_constant_override("outline_size", 0)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_root.add_child(p)
	p.position = screen_pos - Vector2(60, 70)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## True when the mouse is over a HUD control (so map clicks are ignored).
func mouse_over_ui() -> bool:
	var hovered := _root.get_viewport().gui_get_hovered_control()
	return hovered != null and hovered != _root and hovered.mouse_filter == Control.MOUSE_FILTER_STOP
