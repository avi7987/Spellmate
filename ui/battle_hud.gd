class_name BattleHud
extends CanvasLayer
## The battle screen, in the spellbook style (all built in code):
##   top:    both kingdoms' palace health, the turn and phase (plan / action), help, exit
##   bottom: energy, the 8 deck cards, planned moves, powers, palace upgrade,
##           and the big wax seal "בצע!" (execute) - or fast / skip during the action
##   left:   a page about the chosen hero (life, damage, range, power)
##   right:  the summary of the last turn
##   cinema bars and a big title for big moments, a "how to play" page

signal card_pressed(idx: int)
signal ability_pressed(unit_id: int)
signal upgrade_pressed
signal execute_pressed
signal speed_pressed
signal skip_pressed
signal clear_plan_pressed
signal exit_pressed
signal help_pressed

var battle: Battle
var viewer := 0
var cards: Array = []
var _root: Control
var _energy_label: Label
var _energy_note: Label
var _energy_bar: Control
var _turn_label: Label
var _phase_label: Label
var _phase_bar: ProgressBar
var _hint: Label
var _flash: Label
var _abilities: HBoxContainer
var _ability_ids: Array = []
var _upgrade: Button
var _team_bars: Array = []
var _drag_box: Panel
var _speech_root: Control
var _execute: Button
var _action_box: VBoxContainer
var _speed_btn: Button
var _plan_label: Label
var _clear_btn: Button
var _info: PanelContainer
var _info_box: VBoxContainer
var _info_unit := -1
var _summary: PanelContainer
var _bars: Array = []
var _scene_title: Label
var _help: Control
var help_button: Button
var _sky_row: HBoxContainer
var _sky_label: Label
var _sound_btn: Button
var _top_bar: Control
var _name_labels: Array = []
var _bottom_bar: Control
var _side_box: Control


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
	_root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	add_child(_root)
	_build_cinema()
	_speech_root = _layer()
	_build_top()
	_build_bottom()
	_build_info()
	_build_summary()
	_hint = UiKit.label("", 20, UiKit.TEXT, 700)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.position = Vector2(-450, -196)
	_hint.size = Vector2(900, 30)
	_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_hint)
	_flash = UiKit.title("", 50)
	_flash.set_anchors_preset(Control.PRESET_CENTER)
	_flash.position = Vector2(-500, -170)
	_flash.size = Vector2(1000, 90)
	_flash.modulate.a = 0.0
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_flash)
	_drag_box = Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(1.0, 0.85, 0.45, 0.10)
	sb.border_color = Color(1.0, 0.85, 0.45, 0.9)
	sb.set_border_width_all(2)
	_drag_box.add_theme_stylebox_override("panel", sb)
	_drag_box.visible = false
	_drag_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_drag_box)


func _layer() -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(c)
	return c


func _strip(child: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.strip_style())
	p.add_child(child)
	return p


func _build_top() -> void:
	var bar := HBoxContainer.new()
	bar.set_anchors_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 8
	bar.offset_right = -8
	bar.offset_top = 4
	bar.add_theme_constant_override("separation", 8)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(bar)
	_top_bar = bar
	for team in [viewer, 1 - viewer]:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 0)
		v.custom_minimum_size = Vector2(230, 0)
		var name_l := UiKit.label("ממלכת השמש ☀" if team == 0 else "ממלכת האופל ☾", 21, UiKit.TEXT, 800)
		_name_labels.append(name_l)
		v.add_child(name_l)
		var pb := ProgressBar.new()
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(200, 12)
		pb.max_value = 1.0
		pb.step = 0.001
		var fill := StyleBoxFlat.new()
		fill.bg_color = Color(0.85, 0.6, 0.15) if team == 0 else Color(0.45, 0.2, 0.6)
		fill.set_corner_radius_all(4)
		pb.add_theme_stylebox_override("fill", fill)
		v.add_child(pb)
		var info := UiKit.label("", 13, UiKit.TEXT_SOFT)
		v.add_child(info)
		_team_bars.append([team, pb, info])
		bar.add_child(_strip(v))
		if team == viewer:
			var mid := VBoxContainer.new()
			mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
			mid.alignment = BoxContainer.ALIGNMENT_BEGIN
			var center := CenterContainer.new()
			var turn_box := VBoxContainer.new()
			turn_box.add_theme_constant_override("separation", 0)
			_turn_label = UiKit.label("תור 1", 32, UiKit.TEXT, 800)
			turn_box.add_child(_turn_label)
			_phase_label = UiKit.label("", 17, UiKit.ACCENT, 700)
			turn_box.add_child(_phase_label)
			_phase_bar = ProgressBar.new()
			_phase_bar.show_percentage = false
			_phase_bar.custom_minimum_size = Vector2(200, 8)
			_phase_bar.max_value = 1.0
			_phase_bar.step = 0.001
			turn_box.add_child(_phase_bar)
			# the sky in the next turns: plan around day, night and the eclipse
			_sky_row = HBoxContainer.new()
			_sky_row.alignment = BoxContainer.ALIGNMENT_CENTER
			_sky_row.add_theme_constant_override("separation", 6)
			_sky_row.tooltip_text = "יום: אתם חזקים יותר. לילה: האויב חזק יותר. ליקוי: כל הכוחות נטענים."
			_sky_row.mouse_filter = Control.MOUSE_FILTER_PASS
			turn_box.add_child(_sky_row)
			for k in 6:
				var l := UiKit.label("", 22 if k == 0 else 17, UiKit.TEXT, 700)
				_sky_row.add_child(l)
			_sky_label = UiKit.label("", 14, UiKit.TEXT_SOFT, 600)
			turn_box.add_child(_sky_label)
			var strip := _strip(turn_box)
			strip.custom_minimum_size = Vector2(250, 0)
			center.add_child(strip)
			mid.add_child(center)
			bar.add_child(mid)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)
	btns.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_sound_btn = UiKit.button("🔊", UiKit.BUTTON_STEEL, 22)
	_sound_btn.custom_minimum_size = Vector2(52, 52)
	_sound_btn.tooltip_text = "צלילים ומוזיקה"
	_sound_btn.pressed.connect(func():
		var on := Sfx.volume > 0.0 or Music.volume > 0.0
		Sfx.volume = 0.0 if on else 0.8
		Voice.volume = 0.0 if on else 0.7
		Music.set_volume(0.0 if on else 0.45)
		_sound_btn.text = "🔇" if on else "🔊"
		if not on:
			Sfx.play("coin"))
	btns.add_child(_sound_btn)
	var help := UiKit.button("?", UiKit.BUTTON_STEEL, 26)
	help_button = help
	help.custom_minimum_size = Vector2(52, 52)
	help.tooltip_text = "איך משחקים"
	help.pressed.connect(func(): help_pressed.emit())
	btns.add_child(help)
	var ex := UiKit.button("יציאה", UiKit.BUTTON_RED, 18)
	ex.custom_minimum_size = Vector2(86, 52)
	ex.pressed.connect(func(): exit_pressed.emit())
	btns.add_child(ex)
	bar.add_child(btns)


func _build_bottom() -> void:
	var holder := HBoxContainer.new()
	holder.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	holder.offset_top = -172
	holder.offset_bottom = -4
	holder.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_theme_constant_override("separation", 8)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(holder)
	_bottom_bar = holder
	# energy
	var ev := VBoxContainer.new()
	ev.alignment = BoxContainer.ALIGNMENT_CENTER
	ev.add_theme_constant_override("separation", 0)
	ev.add_child(UiKit.label("אנרגיה", 18, UiKit.TEXT, 700))
	_energy_label = UiKit.label("5", 44, Style.CRYSTAL.darkened(0.35), 700)
	_energy_label.add_theme_font_override("font", UiKit.font(700))
	ev.add_child(_energy_label)
	_energy_note = UiKit.label("", 14, UiKit.ACCENT)
	ev.add_child(_energy_note)
	_energy_bar = Control.new()
	_energy_bar.custom_minimum_size = Vector2(110, 12)
	_energy_bar.draw.connect(_draw_energy)
	ev.add_child(_energy_bar)
	var ep := _strip(ev)
	ep.tooltip_text = "אנרגיה מגיעה מכורים שחופרים במכרות הקריסטל.\nבעזרתה מזמנים גיבורים, מטילים קסמים ומפעילים כוחות."
	holder.add_child(ep)
	# cards
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	for i in battle.cards[viewer].size():
		var c := BattleCard.new()
		c.setup(i, battle.cards[viewer][i]["id"])
		c.pressed.connect(func(idx): card_pressed.emit(idx))
		row.add_child(c)
		cards.append(c)
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", UiKit.leather_style(UiKit.BUTTON_BRONZE, 10))
	cp.add_child(row)
	holder.add_child(cp)
	# planned moves, powers, upgrade
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 4)
	side.alignment = BoxContainer.ALIGNMENT_END
	_abilities = HBoxContainer.new()
	_abilities.add_theme_constant_override("separation", 4)
	side.add_child(_abilities)
	var plan_row := HBoxContainer.new()
	_plan_label = UiKit.label("", 15, UiKit.TEXT, 700)
	_plan_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plan_row.add_child(_plan_label)
	_clear_btn = UiKit.button("לבטל הכול", UiKit.BUTTON_STEEL, 14)
	_clear_btn.custom_minimum_size = Vector2(96, 34)
	_clear_btn.pressed.connect(func(): clear_plan_pressed.emit())
	plan_row.add_child(_clear_btn)
	side.add_child(plan_row)
	_upgrade = UiKit.button("", UiKit.BUTTON_BRONZE, 16)
	_upgrade.custom_minimum_size = Vector2(190, 46)
	_upgrade.tooltip_text = "השער מתחזק ומתרפא, והמלך מכה חזק יותר"
	_upgrade.pressed.connect(func(): upgrade_pressed.emit())
	side.add_child(_upgrade)
	# the powers, the plan and the upgrade float above the bottom-right corner
	side.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	side.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	side.grow_vertical = Control.GROW_DIRECTION_BEGIN
	side.offset_right = -10
	side.offset_bottom = -176
	_root.add_child(side)
	_side_box = side
	# execute seal / action controls
	var act := Control.new()
	act.custom_minimum_size = Vector2(136, 150)
	_execute = UiKit.seal_button("בצע!", 132, 34)
	_execute.tooltip_text = "שני הצדדים מבצעים את המהלכים יחד (רווח או Enter)"
	_execute.position = Vector2(2, 8)
	_execute.pressed.connect(func(): execute_pressed.emit())
	act.add_child(_execute)
	_action_box = VBoxContainer.new()
	_action_box.position = Vector2(4, 22)
	_action_box.custom_minimum_size = Vector2(128, 0)
	_speed_btn = UiKit.button("⏩ מהר", UiKit.BUTTON_BRONZE, 18)
	_speed_btn.custom_minimum_size = Vector2(128, 50)
	_speed_btn.pressed.connect(func(): speed_pressed.emit())
	_action_box.add_child(_speed_btn)
	var skip := UiKit.button("⏭ דלג", UiKit.BUTTON_BRONZE, 18)
	skip.custom_minimum_size = Vector2(128, 50)
	skip.tooltip_text = "לדלג ישר לסוף התור (רווח)"
	skip.pressed.connect(func(): skip_pressed.emit())
	_action_box.add_child(skip)
	_action_box.visible = false
	act.add_child(_action_box)
	holder.add_child(act)


func _draw_energy() -> void:
	var n := int(battle.energy_max)
	var e: float = battle.energy[viewer]
	var w := _energy_bar.size.x / n
	for i in n:
		var r := Rect2(Vector2(i * w + 1, 0), Vector2(w - 2, _energy_bar.size.y))
		var full := clampf(e - i, 0.0, 1.0)
		_energy_bar.draw_rect(r, Color(0.25, 0.15, 0.07, 0.3))
		if full > 0.0:
			_energy_bar.draw_rect(Rect2(r.position, Vector2(r.size.x * full, r.size.y)), Style.CRYSTAL.darkened(0.15))


# ------------------------------------------------------------------ hero page

func _build_info() -> void:
	_info = PanelContainer.new()
	_info.add_theme_stylebox_override("panel", UiKit.strip_style())
	_info.position = Vector2(8, 120)
	_info.custom_minimum_size = Vector2(250, 0)
	_info_box = VBoxContainer.new()
	_info_box.add_theme_constant_override("separation", 2)
	_info.add_child(_info_box)
	_info.visible = false
	_root.add_child(_info)


## A page about one unit: picture, what it does, numbers, power.
func show_unit_info(u: BUnit) -> void:
	_info_unit = u.id if u != null else -1
	_info.visible = u != null
	if u == null:
		return
	for c in _info_box.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	var pic := TextureRect.new()
	pic.texture = Portraits.get_tex(u.kind, 0)
	pic.custom_minimum_size = Vector2(64, 64)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(pic)
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var nm := UiKit.label(HeroTexts.name_of(u.kind) if not u.structure else {"gate": "שער", "wall": "חומת מגן"}.get(u.kind, ""), 24, UiKit.TEXT, 800)
	nv.add_child(nm)
	nv.add_child(UiKit.label("ממלכת השמש" if u.team == 0 else "אויב · ממלכת האופל", 14, UiKit.ACCENT if u.team == 1 else UiKit.TEXT_SOFT))
	head.add_child(nv)
	_info_box.add_child(head)
	if not u.structure and HeroTexts.style_of(u.kind) != "":
		var st := UiKit.label("✦ " + HeroTexts.style_of(u.kind), 14, UiKit.GOLD, 600)
		st.custom_minimum_size = Vector2(230, 0)
		st.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_box.add_child(st)
	if not u.structure:
		var role := UiKit.label(HeroTexts.role_of(u.kind), 15, UiKit.TEXT)
		role.custom_minimum_size = Vector2(230, 0)
		role.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_box.add_child(role)
	var stats := GridContainer.new()
	stats.columns = 2
	stats.add_theme_constant_override("h_separation", 12)
	var rows := [["❤ חיים", "%d / %d" % [int(u.hp), int(u.max_hp)]]]
	if u.heal > 0.0:
		rows.append(["✚ ריפוי", "%d בכל פעם" % int(u.heal)])
	elif u.dmg > 0.0:
		rows.append(["⚔ נזק", "%d בכל מכה" % int(u.dmg * battle._level_mult(u))])
	if u.range_ > 0.0 and u.dmg + u.heal > 0.0:
		rows.append(["➶ טווח", ("%d משבצות" % roundi(u.range_)) if u.range_ >= 2.0 else "צמוד"])
	if u.speed > 0.0:
		rows.append(["👣 מהירות", "איטי" if u.speed < 1.0 else ("רגיל" if u.speed < 2.0 else "מהיר")])
	if u.level > 1:
		rows.append(["★ דרגה", str(u.level)])
	for r in rows:
		var a := UiKit.label(r[0], 15, UiKit.TEXT_SOFT, 700)
		a.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		a.autowrap_mode = TextServer.AUTOWRAP_OFF
		stats.add_child(a)
		var b := UiKit.label(r[1], 15, UiKit.TEXT)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		stats.add_child(b)
	_info_box.add_child(stats)
	var ab := battle.ability_of(u)
	if not ab.is_empty():
		_info_box.add_child(UiKit.label("✦ " + HeroTexts.ability_name(ab["id"]) + "  (◆%d)" % int(ab.get("cost", 0)), 16, UiKit.ACCENT, 700))
		var d := UiKit.label(HeroTexts.ability_desc(ab["id"]), 14, UiKit.TEXT)
		d.custom_minimum_size = Vector2(230, 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_box.add_child(d)
	if u.kind == "king":
		var kl := UiKit.label("את המלך אי אפשר לפצוע. " + HeroTexts.MODE_GOAL.get(battle.mode, ""), 15, UiKit.ACCENT, 700)
		kl.custom_minimum_size = Vector2(230, 0)
		kl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_info_box.add_child(kl)
	elif not u.structure and u.team != Battle.NEUTRAL:
		_info_box.add_child(UiKit.label("👣 %d משבצות בתור" % battle.move_tiles(u, battle.next_turn_index()), 15, UiKit.GOLD, 700))


# ------------------------------------------------------------------ summary & cinema

func _build_summary() -> void:
	_summary = PanelContainer.new()
	_summary.add_theme_stylebox_override("panel", UiKit.strip_style())
	_summary.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_summary.position = Vector2(-270, 120)
	_summary.custom_minimum_size = Vector2(260, 0)
	_summary.modulate.a = 0.0
	_summary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_summary)


## What happened in the turn that just ended.
func show_turn_summary(n: int, s: Dictionary, b: Battle) -> void:
	for c in _summary.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 1)
	_summary.add_child(v)
	v.add_child(UiKit.label("סיכום תור %d" % n, 22, UiKit.TEXT, 800))
	var lines := []
	if s.get("kills", 0) > 0:
		lines.append([("⚔ הפלתם אויב אחד" if s["kills"] == 1 else "⚔ הפלתם %d אויבים" % s["kills"]), UiKit.TEXT])
	if s.get("lost", 0) > 0:
		lines.append([("איבדתם גיבור אחד" if s["lost"] == 1 else "איבדתם %d גיבורים" % s["lost"]), UiKit.ACCENT])
	lines.append(["◆ +%d אנרגיה" % int(s.get("energy", 0)), Style.CRYSTAL])

	for st in s.get("structures", []):
		lines.append([("השער של האויב נפל!") if st[1] == 1 else ("השער שלנו נפל!"), UiKit.ACCENT])
	lines.append([mode_line(b, 0), UiKit.GOLD])
	for l in lines:
		var lab := UiKit.label(l[0], 16, l[1], 700)
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		v.add_child(lab)
	var tw := _summary.create_tween()
	_summary.modulate.a = 0.0
	tw.tween_property(_summary, "modulate:a", 1.0, 0.25)
	tw.tween_interval(3.5)
	tw.tween_property(_summary, "modulate:a", 0.0, 0.6)


var _fade: ColorRect


## Fades the whole screen to black (alpha 1) or back (0).
func fade(alpha: float, duration: float) -> void:
	if _fade == null:
		_fade = ColorRect.new()
		_fade.color = Color(0, 0, 0, 0)
		_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fade.z_index = 20
		_root.add_child(_fade)
	var tw := _fade.create_tween()
	tw.tween_property(_fade, "color:a", alpha, duration)
	await tw.finished


func _build_cinema() -> void:
	for top in [true, false]:
		var r := ColorRect.new()
		r.color = Color(0.02, 0.01, 0.0)
		r.set_anchors_preset(Control.PRESET_TOP_WIDE if top else Control.PRESET_BOTTOM_WIDE)
		r.custom_minimum_size = Vector2(0, 0)
		r.offset_bottom = 0 if top else 0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.z_index = 10
		_root.add_child(r)
		_bars.append(r)
	_scene_title = UiKit.title("", 58)
	_scene_title.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_scene_title.position = Vector2(-500, -190)
	_scene_title.size = Vector2(1000, 90)
	_scene_title.modulate.a = 0.0
	_scene_title.z_index = 11
	_scene_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_scene_title)


## Black cinema bars + a big title for a big moment.
func cinematic(on: bool, title: String) -> void:
	var h := 90.0 if on else 0.0
	for c in [_top_bar, _bottom_bar, _side_box, _info, _summary]:
		if c != null:
			c.create_tween().tween_property(c, "modulate:a", 0.0 if on else 1.0, 0.25)
	for i in _bars.size():
		var r: ColorRect = _bars[i]
		var tw := r.create_tween()
		if i == 0:
			tw.tween_property(r, "offset_bottom", h, 0.3).set_trans(Tween.TRANS_CUBIC)
		else:
			tw.tween_property(r, "offset_top", -h, 0.3).set_trans(Tween.TRANS_CUBIC)
	if on:
		_scene_title.text = title
		_scene_title.pivot_offset = _scene_title.size / 2
		_scene_title.scale = Vector2(1.3, 1.3)
		var tw2 := _scene_title.create_tween().set_parallel(true)
		tw2.tween_property(_scene_title, "modulate:a", 1.0, 0.25)
		tw2.tween_property(_scene_title, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		_scene_title.create_tween().tween_property(_scene_title, "modulate:a", 0.0, 0.25)


# ------------------------------------------------------------------ help page

func show_help() -> void:
	if _help != null and is_instance_valid(_help):
		_help.queue_free()
		_help = null
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	_help = dim
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(center)
	var p := UiKit.panel()
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	p.add_child(v)
	v.add_child(UiKit.title("איך משחקים", 40))
	for t in HeroTexts.HOW_TO_PLAY:
		v.add_child(UiKit.illuminated(t, 19, 640))
	var close := UiKit.button("הבנתי!", UiKit.BUTTON_RED, 22)
	close.pressed.connect(func():
		dim.queue_free()
		_help = null)
	v.add_child(close)


# ------------------------------------------------------------------ every frame

func set_phase(phase: int, turn: int, _t: float) -> void:
	_turn_label.text = "תור %d" % turn
	var planning := phase == BattleScreen.Phase.PLAN
	_execute.visible = planning
	_action_box.visible = phase == BattleScreen.Phase.ACTION or phase == BattleScreen.Phase.SCENE
	if planning:
		_execute.pivot_offset = _execute.size / 2
		_execute.scale = Vector2(0.6, 0.6)
		_execute.create_tween().tween_property(_execute, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func refresh(bs: BattleScreen) -> void:
	if battle == null:
		return
	if _name_labels.size() > 1 and bs.rival.has("rival_name"):
		_name_labels[1].text = "☾ " + String(bs.rival["rival_name"])
	var planning := bs.phase == BattleScreen.Phase.PLAN
	var e: float = battle.energy[viewer]
	var free := bs.free_energy()
	_energy_label.text = str(int(free))
	_energy_note.text = ("%d שמורים לתכנון" % int(e - free)) if e - free > 0.0 else ""
	_energy_bar.queue_redraw()
	_turn_label.text = "תור %d" % bs.turn
	match bs.phase:
		BattleScreen.Phase.PLAN:
			_phase_label.text = "תכנון · הזמן עוצר"
			_phase_bar.value = 0.0
		BattleScreen.Phase.ACTION, BattleScreen.Phase.SCENE, BattleScreen.Phase.ARENA:
			_phase_label.text = "⚔ פעולה!" + (" ×2.5" if bs.speed > 1.0 else "")
			_phase_bar.value = 1.0 - bs._turn_left / BattleScreen.TURN_SECONDS
		_:
			_phase_label.text = ""
	_speed_btn.text = "▶ רגיל" if bs.speed > 1.0 else "⏩ מהר"
	var now_turn := int(battle.time / Battle.TURN)
	var icons := { "day": "☀", "night": "☾", "eclipse": "◐" }
	var cols := { "day": UiKit.GOLD, "night": Color(0.7, 0.7, 1.0), "eclipse": Color(1.0, 0.5, 0.4) }
	for k in _sky_row.get_child_count():
		var sky := battle.sky_at(now_turn + k)
		var l: Label = _sky_row.get_child(k)
		l.text = icons[sky]
		l.add_theme_color_override("font_color", cols[sky])
		l.modulate.a = 1.0 if k == 0 else 0.65
	_sky_label.text = {"day": "יום · אתם חזקים יותר", "night": "לילה · האויב חזק יותר", "eclipse": "ליקוי · כל הכוחות נטענו"}[battle.sky()]
	_execute.visible = planning
	_action_box.visible = bs.phase in [BattleScreen.Phase.ACTION, BattleScreen.Phase.SCENE, BattleScreen.Phase.ARENA]
	_action_box.modulate.a = 1.0
	for i in cards.size():
		var c: BattleCard = cards[i]
		var wait := battle.card_wait(viewer, i)
		c.set_state(wait, free >= battle.card_cost(c.card_id) or bs.is_planned_card(i), bs.is_planned_card(i) or i == bs._chosen_card, BattleScreen.TURN_SECONDS)
	var cost := battle.palace_upgrade_cost(viewer)
	if cost < 0:
		_upgrade.text = "הארמון בדרגה המקסימלית"
		_upgrade.disabled = true
	else:
		_upgrade.text = "לשדרג ארמון · %d" % cost
		_upgrade.disabled = free < cost or not planning
	var n_cards := bs.plan.filter(func(p): return p["kind"] == "card").size()
	var n_pow := bs.plan.size() - n_cards
	_plan_label.text = ("מתוכנן: %d קלפים, %d כוחות" % [n_cards, n_pow]) if not bs.plan.is_empty() else ""
	_clear_btn.visible = planning and not bs.plan.is_empty()
	for t in _team_bars:
		var team: int = t[0]
		# the bar shows how close this kingdom is to winning the game mode
		t[1].value = battle.mode_progress(team)
		t[2].text = mode_line(battle, team)
	_refresh_abilities(bs)
	if _info.visible and _info_unit >= 0 and battle.unit(_info_unit) == null:
		_info.visible = false


func _refresh_abilities(bs: BattleScreen) -> void:
	var ids := []
	for id in bs.selected:
		var u := battle.unit(id)
		if u != null and not battle.ability_of(u).is_empty():
			ids.append(id)
	ids = ids.slice(0, 5)
	if ids != _ability_ids:
		_ability_ids = ids
		for c in _abilities.get_children():
			c.queue_free()
		for id in ids:
			var u := battle.unit(id)
			var ab := battle.ability_of(u)
			var b := UiKit.button("", UiKit.BUTTON_PURPLE, 14)
			b.custom_minimum_size = Vector2(104, 58)
			b.icon = Portraits.get_tex(u.kind, 0)
			b.expand_icon = true
			b.add_theme_constant_override("icon_max_width", 30)
			b.tooltip_text = "%s - %s\n%s" % [HeroTexts.name_of(u.kind), HeroTexts.ability_name(ab["id"]), HeroTexts.ability_desc(ab["id"])]
			b.pressed.connect(func(): ability_pressed.emit(id))
			b.set_meta("unit", id)
			_abilities.add_child(b)
	var free := bs.free_energy()
	var n := 0
	for b in _abilities.get_children():
		var u := battle.unit(b.get_meta("unit"))
		if u == null:
			continue
		var ab := battle.ability_of(u)
		var wait := u.ability_ready_at - battle.time
		var key := " Q" if n == 0 else ""
		n += 1
		if bs.is_planned_unit(u.id):
			b.text = "%s\n✔ מתוכנן" % HeroTexts.ability_name(ab["id"])
			b.disabled = false
		elif wait > 0.0:
			b.text = "%s\nעוד %d תורות" % [HeroTexts.ability_name(ab["id"]), ceili(wait / BattleScreen.TURN_SECONDS)]
			b.disabled = true
		else:
			b.text = "%s%s\n◆%d" % [HeroTexts.ability_name(ab["id"]), key, int(ab.get("cost", 0))]
			b.disabled = free < float(ab.get("cost", 0)) or bs.phase != BattleScreen.Phase.PLAN


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


## A speech bubble (a torn note of parchment) over a character for a moment.
func speech(screen_pos: Vector2, text: String) -> void:
	if text == "":
		return
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.strip_style())
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UiKit.TEXT)
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_font_override("font", UiKit.font(700))
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_speech_root.add_child(p)
	p.position = screen_pos - Vector2(70, 80)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.8)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## One short line: how far this kingdom got in the game mode.
static func mode_line(battle: Battle, team: int) -> String:
	var g := battle.gate(1 - team)
	var whose := "שלהם" if team == 0 else "שלנו"
	var gate_txt := ("השער %s %d%%" % [whose, int(100 * g.hp / g.max_hp)]) if g != null else "השער %s פרוץ" % whose
	match battle.mode:
		"mate":
			var zone := battle.king_zone(1 - team)
			return "%s · מט: %d/%d" % [gate_txt, battle.mate_cells[1 - team].size(), zone.size()]
		"crown":
			for cr in battle.crowns:
				if cr["team"] != team and cr["carrier"] >= 0:
					return "הכתר שלהם בידיים שלנו!" if team == 0 else "הכתר שלנו אצלם!"
			return "%s · הכתר על הכסא" % gate_txt
		"throne":
			return "%s · על הכסא: %d/3 תורות" % [gate_txt, int(battle.throne_time[team] / Battle.TURN)]
		"runes":
			return "רונות אצל המלך: %d/3" % battle.rune_count[team]
	return gate_txt
