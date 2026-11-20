class_name BaseScreen
extends Node
## The home village between battles (like a small Clash of Clans base):
##   - 3D village: palace, buildings (scaffolding until built), decorations,
##     your heroes walking around. Click a building to build / upgrade it.
##   - bottom bar: Village / Heroes / Deck / Chests, map size and BATTLE.
##   - top bar: gold, trophies and arena.

const ENV := "res://assets/environment/kaykit/"
const CHEST := "res://assets/props/chest_gold.glb"

## id -> [model, position, scale, hebrew name, description]
const BUILDINGS := {
	"palace": ["building_castle_blue", Vector3(0, 0, -4.2), 1.15, "הארמון", "כל דרגה: השער, המגדלים והמלך חזקים יותר בקרב (+8%)"],
	"mine": ["building_mine_blue", Vector3(-5.2, 0, -1.2), 1.0, "מכרה הקריסטלים", "כל דרגה: עוד אנרגיה אחת בתחילת כל קרב"],
	"barracks": ["building_barracks_blue", Vector3(5.2, 0, -1.2), 1.0, "מגורי החיילים", "פותח את קלף 'חומת מגן'"],
	"mage_tower": ["building_tower_B_blue", Vector3(-4.6, 0, -5.4), 1.0, "מגדל הקוסמים", "פותח את המלכה, המרפאה, מכשפת הקרח וקוסם האש"],
	"forge": ["building_blacksmith_blue", Vector3(4.6, 0, -5.4), 1.0, "הנפחייה", "פותחת את הענק והבליסטרה"],
	"shadow_den": ["building_home_B_blue", Vector3(-6.2, 0, 2.8), 1.0, "מאורת הצללים", "פותחת את מתנקש הצללים"],
	"dragon_roost": ["building_tower_catapult_blue", Vector3(6.2, 0, 2.8), 1.0, "קן הדרקון", "פותח את הדרקון"],
}
const DECOR := {
	"well": ["building_well_blue", Vector3(-1.8, 0, 1.6), 0.9, "באר", "קישוט"],
	"market": ["building_market_blue", Vector3(2.4, 0, 2.4), 0.9, "שוק", "קישוט"],
	"church": ["building_church_blue", Vector3(-8.4, 0, -3.6), 0.9, "כנסייה", "קישוט"],
	"windmill": ["building_windmill_blue", Vector3(8.4, 0, -3.6), 0.9, "טחנת רוח", "קישוט"],
	"archery": ["building_archeryrange_blue", Vector3(0, 0, 4.6), 0.9, "מטווח", "קישוט"],
}

var app: Node
var profile: Profile
var _world: Node3D
var _cam: Camera3D
var _ui: CanvasLayer
var _root: Control
var _gold: Label
var _trophies: Label
var _panel_holder: Control
var _panel: Control
var _chest_btn: Button
var _size_btns: Dictionary = {}
var _quest_btn: Button
var _nodes: Dictionary = {}       ## building id -> Node3D (for clicking)
var _walkers: Array = []
var _orbit := 0.0
var _focus := Vector3(0, 0, -0.5)
var _deck_slot := -1


func open() -> void:
	profile = app.profile
	profile.refresh_quests()
	_world = Node3D.new()
	add_child(_world)
	_cam = Camera3D.new()
	_cam.fov = 40
	_world.add_child(_cam)
	_cam.make_current()
	_build_village()
	_build_ui()
	_refresh()
	Music.play("base")
	await app.portraits.render(BattleData.hero_ids(), 0)
	if _panel != null and is_instance_valid(_panel):
		for c in _panel.find_children("*", "BattleCard", true, false):
			c.queue_redraw()


func _exit_tree() -> void:
	if app != null and app.camera_rig != null:
		app.camera_rig.make_current()


func _process(delta: float) -> void:
	_orbit += delta * 0.04
	var yaw := sin(_orbit) * 0.35
	var off := Vector3(sin(yaw), 0.0, cos(yaw)) * 17.0 + Vector3(0, 13.0, 0)
	_cam.position = _cam.position.lerp(_focus + off, minf(1.0, delta * 3.0))
	_cam.look_at(_focus)
	for w in _walkers:
		_walk(w, delta)


# ------------------------------------------------------------------ village

func _build_village() -> void:
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(200, 200)
	ground.mesh = pm
	ground.material_override = Style.matte(Style.GRASS.darkened(0.15))
	ground.position.y = -0.05
	_world.add_child(ground)
	var island := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 11.5
	cyl.bottom_radius = 12.2
	cyl.height = 0.4
	island.mesh = cyl
	island.material_override = Style.matte(Style.GRASS_TILE)
	island.position.y = -0.2
	_world.add_child(island)
	# stone paths
	for p in [[Vector3(0, 0.01, 0), Vector3(1.6, 0.02, 9.0)], [Vector3(0, 0.01, -0.6), Vector3(11.0, 0.02, 1.4)]]:
		var mi := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = p[1]
		mi.mesh = b
		mi.material_override = Style.matte(Style.TILE_LIGHT.darkened(0.15))
		mi.position = p[0]
		_world.add_child(mi)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 26:
		var a := rng.randf() * TAU
		var r := rng.randf_range(9.5, 13.5)
		_model("tree_single_" + ("A" if i % 2 == 0 else "B"), Vector3(cos(a) * r, 0, sin(a) * r), rng.randf_range(0.7, 1.0), rng.randf() * 360.0)
	_rebuild_buildings()
	# heroes from the collection stroll around the village
	var heroes := profile.available_cards().filter(func(c): return not BattleData.is_spell(c))
	heroes.shuffle()
	for id in heroes.slice(0, 6):
		var m := PieceModelFactory.build_hero(id, 0)
		_world.add_child(m)
		m.position = Vector3(rng.randf_range(-4, 4), 0, rng.randf_range(-1, 3.5))
		_walkers.append({ "node": m, "target": m.position, "wait": rng.randf_range(0, 3), "anims": m.get_meta("anims", {}), "player": (m.get_meta("player") if m.has_meta("player") else null), "moving": false })
	var king := PieceModelFactory.build_hero("king", 0)
	_world.add_child(king)
	king.position = Vector3(0, 0, -1.6)
	var kp: AnimationPlayer = (king.get_meta("player") if king.has_meta("player") else null)
	if kp != null and king.get_meta("anims", {}).has("idle"):
		kp.get_animation(king.get_meta("anims")["idle"]).loop_mode = Animation.LOOP_LINEAR
		kp.play(king.get_meta("anims")["idle"])


func _model(name: String, pos: Vector3, s: float, yaw: float = 0.0) -> Node3D:
	var path := ENV + name + ".gltf"
	if not ResourceLoader.exists(path):
		return null
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = pos
	n.scale = Vector3.ONE * s
	n.rotation_degrees.y = yaw
	_world.add_child(n)
	return n


func _rebuild_buildings() -> void:
	for id in _nodes:
		if is_instance_valid(_nodes[id]):
			_nodes[id].queue_free()
	_nodes.clear()
	for id in BUILDINGS:
		var d: Array = BUILDINGS[id]
		var built := int(profile.buildings.get(id, 0)) > 0
		var holder := Node3D.new()
		holder.position = d[1]
		_world.add_child(holder)
		var n := _model(d[0] if built else "building_scaffolding", Vector3.ZERO, d[2] * (1.0 if built else 0.85))
		if n != null:
			n.reparent(holder, false)
		_sign(holder, d[3] + ("" if built else "\n🪙 %d" % profile.building_cost(id)), built, id)
		_nodes[id] = holder
	for id in DECOR:
		var d: Array = DECOR[id]
		var bought := profile.decorations.has(id)
		var holder := Node3D.new()
		holder.position = d[1]
		_world.add_child(holder)
		if bought:
			var n := _model(d[0], Vector3.ZERO, d[2])
			if n != null:
				n.reparent(holder, false)
		else:
			var plot := MeshInstance3D.new()
			var c := CylinderMesh.new()
			c.top_radius = 0.9
			c.bottom_radius = 0.95
			c.height = 0.06
			plot.mesh = c
			plot.material_override = Style.matte(Color(0.42, 0.33, 0.22))
			holder.add_child(plot)
			_sign(holder, "%s\n🪙 %d" % [d[3], int(Profile.meta()["decorations"][id]["cost"])], false, id, 0.55)
		_nodes[id] = holder


func _sign(parent: Node3D, text: String, built: bool, id: String, scale_k: float = 1.0) -> void:
	var l := Label3D.new()
	l.text_direction = TextServer.DIRECTION_RTL
	l.text = text
	l.font = UiKit.font(700)
	l.font_size = int((44 if built else 48) * scale_k)
	l.outline_size = 16
	l.outline_modulate = UiKit.OUTLINE
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.modulate = UiKit.GOLD if built else UiKit.TEXT
	l.position = Vector3(0, 4.6 if id == "palace" else 2.6, 0)
	if built and id in ["palace", "mine"]:
		l.text = "%s (%d)" % [text, int(profile.buildings[id])]
	parent.add_child(l)


func _walk(w: Dictionary, delta: float) -> void:
	var n: Node3D = w["node"]
	if not is_instance_valid(n):
		return
	var player: AnimationPlayer = w["player"]
	var anims: Dictionary = w["anims"]
	if w["wait"] > 0.0:
		w["wait"] -= delta
		if w["moving"] and player and anims.has("idle"):
			player.get_animation(anims["idle"]).loop_mode = Animation.LOOP_LINEAR
			player.play(anims["idle"], 0.2)
		w["moving"] = false
		if w["wait"] <= 0.0:
			w["target"] = Vector3(randf_range(-4.5, 4.5), 0, randf_range(-1.5, 4.0))
		return
	var to: Vector3 = w["target"] - n.position
	if to.length() < 0.1:
		w["wait"] = randf_range(2.0, 6.0)
		return
	if not w["moving"] and player and anims.has("move"):
		player.get_animation(anims["move"]).loop_mode = Animation.LOOP_LINEAR
		player.play(anims["move"], 0.2)
	w["moving"] = true
	n.position += to.normalized() * minf(to.length(), delta * 1.1)
	n.rotation.y = lerp_angle(n.rotation.y, atan2(to.x, to.z), delta * 6.0)


# ------------------------------------------------------------------ UI

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiKit.make_theme()
	_root.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_ui.add_child(_root)
	# top bar
	var top := HBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 14
	top.offset_right = -14
	top.offset_top = 10
	top.add_theme_constant_override("separation", 12)
	top.alignment = BoxContainer.ALIGNMENT_BEGIN
	_root.add_child(top)
	var logo_box := VBoxContainer.new()
	logo_box.add_theme_constant_override("separation", -6)
	var logo := UiKit.title("Spellmate", 40)
	logo.add_theme_font_override("font", UiKit.font(700))
	logo_box.add_child(logo)
	logo_box.add_child(UiKit.label("קרב הממלכות", 18, UiKit.TEXT_SOFT, 600))
	var logo_strip := PanelContainer.new()
	logo_strip.add_theme_stylebox_override("panel", UiKit.strip_style())
	logo_strip.add_child(logo_box)
	top.add_child(logo_strip)
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(gap)
	_trophies = _stat_box(top, Color(1, 0.85, 0.5))
	_gold = _stat_box(top, UiKit.GOLD)
	var settings := UiKit.button("⚙", UiKit.BUTTON_BRONZE, 24)
	settings.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	settings.custom_minimum_size = Vector2(54, 50)
	settings.pressed.connect(func(): _open(_settings_panel()))
	top.add_child(settings)
	# bottom bar
	var bottom := HBoxContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_top = -126
	bottom.offset_bottom = -12
	bottom.offset_left = 14
	bottom.offset_right = -14
	bottom.add_theme_constant_override("separation", 10)
	_root.add_child(bottom)
	for t in [["🏰 כפר", func(): _close_panel()], ["⭐ גיבורים", func(): _open(_heroes_panel())], ["🃏 חפיסה", func(): _open(_deck_panel())], ["📖 ספר הגיבורים", func(): _open(_book_panel("soldier"))]]:
		var b := UiKit.button(t[0], UiKit.BUTTON_BRONZE, 20)
		b.size_flags_vertical = Control.SIZE_SHRINK_END
		b.custom_minimum_size = Vector2(124 if t[0].length() < 10 else 170, 62)
		b.pressed.connect(func(): Sfx.play("click"); t[1].call())
		bottom.add_child(b)
	_quest_btn = UiKit.button("📜 משימות", UiKit.BUTTON_GREEN, 20)
	_quest_btn.custom_minimum_size = Vector2(150, 62)
	_quest_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_quest_btn.pressed.connect(func(): Sfx.play("click"); _open(_quests_panel()))
	bottom.add_child(_quest_btn)
	_chest_btn = UiKit.button("🎁 תיבות", UiKit.BUTTON_PURPLE, 20)
	_chest_btn.custom_minimum_size = Vector2(140, 62)
	_chest_btn.size_flags_vertical = Control.SIZE_SHRINK_END
	_chest_btn.pressed.connect(func(): Sfx.play("click"); _open(_chests_panel()))
	bottom.add_child(_chest_btn)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(spacer)
	var fight := UiKit.seal_button("לקרב!", 120, 32)
	fight.position.y = -40
	fight.pressed.connect(func():
		Sfx.play("click")
		_open(_world_panel()))
	bottom.add_child(fight)
	_panel_holder = Control.new()
	_panel_holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_panel_holder)


func _stat_box(parent: Control, color: Color) -> Label:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiKit.strip_style())
	var l := UiKit.label("", 24, UiKit.TEXT, 700)
	l.autowrap_mode = TextServer.AUTOWRAP_OFF
	p.add_child(l)
	parent.add_child(p)
	return l


func _refresh() -> void:
	_gold.text = "🪙 %d" % profile.gold
	var a := profile.arena()
	_trophies.text = "🏆 %d · %s" % [profile.trophies, a["name"]]
	_chest_btn.text = "🎁 תיבות (%d)" % profile.chests.size()
	var ready := profile.quests_ready()
	_quest_btn.text = "📜 משימות" + (" (%d!)" % ready if ready > 0 else "")



func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var best := ""
		var best_d := 90.0
		for id in _nodes:
			var n: Node3D = _nodes[id]
			if not is_instance_valid(n):
				continue
			var p := _cam.unproject_position(n.global_position + Vector3(0, 0.9, 0))
			var d := p.distance_to(event.position)
			if d < best_d:
				best_d = d
				best = id
		if best != "":
			Sfx.play("click")
			_open(_building_panel(best))


func _open(panel: Control, low: bool = false) -> void:
	_close_panel(false)
	_panel = panel
	_panel_holder.add_child(panel)
	await get_tree().process_frame
	if not is_instance_valid(panel):
		return
	panel.position = (_root.size - panel.size) / 2 + Vector2(0, -20)
	if low:
		panel.position.y = _root.size.y - panel.size.y - 100
	panel.pivot_offset = panel.size / 2
	panel.scale = Vector2(0.85, 0.85)
	panel.create_tween().tween_property(panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _close_panel(reset_focus: bool = true) -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.queue_free()
	_panel = null
	if reset_focus:
		_focus = Vector3(0, 0, -0.5)


func _reopen(maker: Callable) -> void:
	_refresh()
	_open(maker.call())


func _frame(title: String, accent: Color = UiKit.GOLD, width: float = 620) -> Array:
	var p := UiKit.panel(accent)
	p.custom_minimum_size = Vector2(width, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var head := HBoxContainer.new()
	var t := UiKit.title(title, 32)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var x := UiKit.button("✕", UiKit.BUTTON_STEEL, 18)
	x.custom_minimum_size = Vector2(46, 42)
	x.pressed.connect(func(): Sfx.play("click"); _close_panel())
	head.add_child(x)
	v.add_child(head)
	return [p, v]


# ---------------------------------------------------------------- building

func _building_panel(id: String) -> Control:
	var is_decor := DECOR.has(id)
	var d: Array = DECOR[id] if is_decor else BUILDINGS[id]
	_focus = d[1] + Vector3(0, 0, 1.0)
	var f := _frame(d[3])
	var v: VBoxContainer = f[1]
	v.add_child(UiKit.label(d[4], 20, UiKit.TEXT))
	if is_decor:
		if profile.decorations.has(id):
			v.add_child(UiKit.label("כבר שלכם! הכפר יפה יותר 🙂", 20, UiKit.TEXT, 700))
		else:
			var cost := int(Profile.meta()["decorations"][id]["cost"])
			var b := UiKit.button("לקנות · 🪙 %d" % cost, UiKit.BUTTON_BRONZE, 22)
			b.disabled = profile.gold < cost
			b.pressed.connect(func():
				if profile.buy_decoration(id):
					Sfx.play("build")
					profile.save()
					_rebuild_buildings()
					_reopen(func(): return _building_panel(id)))
			v.add_child(b)
		return f[0]
	var lvl := int(profile.buildings.get(id, 0))
	var meta_b: Dictionary = Profile.meta()["buildings"][id]
	var max_l := int(meta_b["max"])
	v.add_child(UiKit.label("דרגה %d מתוך %d" % [lvl, max_l] if max_l > 1 else ("בנוי ✔" if lvl > 0 else "עוד לא בנוי"), 20, UiKit.TEXT_SOFT))
	var unlocks: Array = meta_b.get("unlocks", [])
	if not unlocks.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		for c in unlocks:
			var card := BattleCard.new()
			card.setup(0, c)
			card.key_hint = ""
			card.set_state(0.0, lvl > 0, false)
			row.add_child(card)
		v.add_child(row)
	if lvl < max_l:
		var need := int(meta_b.get("trophies", 0))
		var b := UiKit.button(("לבנות" if lvl == 0 else "לשדרג") + " · 🪙 %d" % profile.building_cost(id), UiKit.BUTTON_BRONZE, 22)
		b.disabled = not profile.can_build(id)
		if profile.trophies < need:
			v.add_child(UiKit.label("צריך עוד %d גביעים 🏆" % (need - profile.trophies), 18, UiKit.ACCENT))
		elif profile.gold < profile.building_cost(id):
			v.add_child(UiKit.label("אין מספיק זהב. נצחו בקרבות ופתחו תיבות!", 18, UiKit.ACCENT))
		b.pressed.connect(func():
			if profile.build(id):
				Sfx.play("build")
				profile.save()
				_rebuild_buildings()
				_reopen(func(): return _building_panel(id)))
		v.add_child(b)
	return f[0]


# ---------------------------------------------------------------- heroes

func _heroes_panel() -> Control:
	var f := _frame("הגיבורים שלכם", UiKit.GOLD, 900)
	var v: VBoxContainer = f[1]
	v.add_child(UiKit.label("⭐ ניסיון מקבלים בקרבות ובתיבות. עם מספיק ניסיון וזהב משדרגים גיבור, וכל דרגה מוסיפה לו 10% חיים ונזק.", 16, UiKit.TEXT_SOFT))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(860, 430)
	v.add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	scroll.add_child(grid)
	var all := BattleData.hero_ids().filter(func(h): return h != "king") + BattleData.spell_ids()
	for id in all:
		var box := VBoxContainer.new()
		box.custom_minimum_size = Vector2(160, 0)
		var card := BattleCard.new()
		card.setup(0, id)
		card.key_hint = ""
		var owned := profile.available_cards().has(id)
		card.set_state(0.0, owned, false)
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		box.add_child(card)
		if not owned:
			box.add_child(UiKit.label("🔒 " + _unlock_building(id), 14, UiKit.TEXT_SOFT))
		elif BattleData.is_spell(id):
			box.add_child(UiKit.label("קלף קסם", 14, UiKit.TEXT_SOFT))
		else:
			var h: Dictionary = profile.heroes.get(id, { "level": 1, "xp": 0 })
			box.add_child(UiKit.label("דרגה %d · ⭐ %d מתוך %d" % [int(h["level"]), int(h["xp"]), profile.xp_needed(id)], 15, UiKit.TEXT))
			var b := UiKit.button("לשדרג · 🪙 %d" % profile.upgrade_cost(id), UiKit.BUTTON_BRONZE, 15)
			b.custom_minimum_size = Vector2(0, 40)
			b.disabled = not profile.can_upgrade(id)
			b.pressed.connect(func():
				if profile.upgrade_hero(id):
					Sfx.play("upgrade")
					Voice.babble(id)
					profile.save()
					_reopen(_heroes_panel))
			box.add_child(b)
		grid.add_child(box)
	return f[0]


func _unlock_building(card: String) -> String:
	for b in Profile.meta()["buildings"]:
		if card in Profile.meta()["buildings"][b].get("unlocks", []):
			return "נפתח כשבונים את " + BUILDINGS[b][3]
	return ""


# ---------------------------------------------------------------- deck

func _deck_panel() -> Control:
	var f := _frame("החפיסה שלכם · 8 קלפים", UiKit.GOLD, 920)
	var v: VBoxContainer = f[1]
	v.add_child(UiKit.label("לחצו על קלף בחפיסה, ואז על קלף מהאוסף כדי להחליף ביניהם", 17, UiKit.TEXT_SOFT))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	for i in profile.deck.size():
		var c := BattleCard.new()
		c.setup(i, profile.deck[i])
		c.chosen_text = "להחליף?"
		c.set_state(0.0, true, i == _deck_slot)
		c.pressed.connect(func(idx):
			Sfx.play("select")
			_deck_slot = -1 if _deck_slot == idx else idx
			_reopen(_deck_panel))
		row.add_child(c)
	var cost := 0.0
	for c in profile.deck:
		cost += BattleData.card(c).get("cost", 0)
	v.add_child(UiKit.label("מחיר ממוצע: %.1f אנרגיה · %s" % [cost / 8.0, "יש כורה ✔" if profile.deck.has("miner") else "⚠ אין כורה בחפיסה!"], 16, UiKit.TEXT_SOFT))
	v.add_child(UiKit.title("האוסף", 24, UiKit.TEXT))
	var others := HFlowContainer.new()
	others.custom_minimum_size = Vector2(880, 0)
	others.add_theme_constant_override("h_separation", 8)
	others.add_theme_constant_override("v_separation", 8)
	v.add_child(others)
	for id in profile.available_cards():
		if profile.deck.has(id):
			continue
		var c := BattleCard.new()
		c.setup(0, id)
		c.key_hint = ""
		c.set_state(0.0, _deck_slot >= 0, false)
		c.pressed.connect(func(_i):
			if _deck_slot >= 0 and profile.set_deck_card(_deck_slot, id):
				Sfx.play("order")
				_deck_slot = -1
				profile.save()
				_reopen(_deck_panel))
		others.add_child(c)
	if others.get_child_count() == 0:
		others.add_child(UiKit.label("כל הקלפים שלכם כבר בחפיסה. בנו מבנים בכפר כדי לפתוח עוד!", 17, UiKit.TEXT_SOFT))
	return f[0]


# ---------------------------------------------------------------- chests

func _chests_panel() -> Control:
	var f := _frame("תיבות אוצר", Color(0.8, 0.55, 1.0))
	var v: VBoxContainer = f[1]
	if profile.chests.is_empty():
		v.add_child(UiKit.label("אין תיבות כרגע. כל ניצחון נותן תיבה (אפשר לשמור עד %d)" % int(Profile.meta()["chest_slots"]), 20, UiKit.TEXT_SOFT))
		return f[0]
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	for i in profile.chests.size():
		var type: String = profile.chests[i]
		var b := UiKit.button("🎁\nתיבת %s\nלפתוח!" % ChestNames.name_of(type), UiKit.BUTTON_PURPLE, 18)
		b.custom_minimum_size = Vector2(130, 120)
		b.add_theme_color_override("font_color", ChestNames.COLORS[type])
		b.pressed.connect(func(): _open_chest(i))
		row.add_child(b)
	return f[0]


## The chest appears in the village, shakes, the lid flies open and the rewards pop out.
func _open_chest(idx: int) -> void:
	_close_panel()
	var type: String = profile.chests[idx]
	var res := profile.open_chest(idx)
	profile.save()
	_refresh()
	_focus = Vector3(0, 0, 3.0)
	var chest := (load(CHEST) as PackedScene).instantiate() as Node3D
	_world.add_child(chest)
	chest.position = Vector3(0, 0, 1.2)
	chest.scale = Vector3.ONE * 0.01
	var tint := ChestNames.COLORS[type] as Color
	for mi in chest.find_children("*", "MeshInstance3D", true, false):
		if type != "gold":
			var m := StandardMaterial3D.new()
			m.albedo_color = tint
			m.metallic = 0.4 if type == "silver" else 0.0
			m.roughness = 0.5
			mi.material_override = m
	var tw := chest.create_tween()
	tw.tween_property(chest, "scale", Vector3.ONE * 2.2, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	for i in 6:
		tw.tween_property(chest, "rotation_degrees:z", 8.0 if i % 2 == 0 else -8.0, 0.07)
	tw.tween_property(chest, "rotation_degrees:z", 0.0, 0.07)
	await tw.finished
	var lid := chest.find_child("chest_gold_lid", true, false) as Node3D
	if lid != null:
		lid.create_tween().tween_property(lid, "rotation_degrees:x", -110.0, 0.25).set_trans(Tween.TRANS_BACK)
	Sfx.play("chest")
	Effects.burst(_world, chest.position + Vector3(0, 1.0, 0), tint.lightened(0.3), 60, 4.0, 0.1)
	Effects.pillar(_world, chest.position, UiKit.GOLD, 5.0, 1.0)
	# rewards panel
	var f := _frame("תיבת " + ChestNames.name_of(type), tint)
	var v: VBoxContainer = f[1]
	v.add_child(UiKit.title("🪙 +%d זהב" % int(res["gold"]), 34, UiKit.GOLD))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var k := 0
	for id in res["xp"]:
		var box := VBoxContainer.new()
		var c := BattleCard.new()
		c.setup(0, id)
		c.key_hint = ""
		box.add_child(c)
		box.add_child(UiKit.label("⭐ +%d" % int(res["xp"][id]), 20, Color(0.6, 0.9, 1.0), 800))
		box.modulate.a = 0.0
		box.create_tween().tween_property(box, "modulate:a", 1.0, 0.3).set_delay(0.2 + k * 0.25)
		k += 1
		row.add_child(box)
	_open(f[0], true)
	await get_tree().create_timer(0.3).timeout
	Voice.babble(res["xp"].keys()[0] if not res["xp"].is_empty() else "king")
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(chest):
		var t2 := chest.create_tween()
		t2.tween_property(chest, "scale", Vector3.ONE * 0.01, 0.3)
		t2.tween_callback(chest.queue_free)


# ---------------------------------------------------------------- daily quests

func _quests_panel() -> Control:
	var f := _frame("משימות יומיות", UiKit.GOOD, 700)
	var v: VBoxContainer = f[1]
	v.add_child(UiKit.label("כל יום יש משימות חדשות. השלימו אותן וקבלו זהב!", 18, UiKit.TEXT_SOFT))
	for i in profile.quests.size():
		var q: Dictionary = profile.quests[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var t := UiKit.label(Profile.quest_text(q), 22, UiKit.TEXT, 700)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		col.add_child(t)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(320, 18)
		bar.max_value = float(q["goal"])
		bar.value = float(q["progress"])
		col.add_child(bar)
		col.add_child(UiKit.label("%d מתוך %d" % [int(q["progress"]), int(q["goal"])], 15, UiKit.TEXT_SOFT))
		row.add_child(col)
		var done: bool = int(q["progress"]) >= int(q["goal"])
		var b: Button
		if q["claimed"]:
			b = UiKit.button("✔ התקבל", UiKit.BUTTON_GREY, 18)
			b.disabled = true
		else:
			b = UiKit.button("לקבל · 🪙 %d" % int(q["gold"]), UiKit.BUTTON_GREEN if done else UiKit.BUTTON_STEEL, 18)
			b.disabled = not done
			b.pressed.connect(func():
				if profile.claim_quest(i) > 0:
					Sfx.play("reward")
					profile.save()
					_reopen(_quests_panel))
		b.custom_minimum_size = Vector2(170, 56)
		row.add_child(b)
		v.add_child(row)
	return f[0]


# ---------------------------------------------------------------- choose a world

## Before a battle: pick the world (biome) and the map size.
func _world_panel() -> Control:
	var f := _frame("איפה נלחמים?", UiKit.GOLD, 1000)
	var v: VBoxContainer = f[1]
	var chosen: String = profile.settings.get("world", "meadow")
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 10)
	v.add_child(grid)
	for id in BattleData.biome_ids():
		var w := BattleData.biome(id)
		var tile := WorldTile.new()
		tile.setup(id, w, id == chosen)
		tile.pressed.connect(func():
			profile.settings["world"] = id
			Sfx.play("select")
			_reopen(_world_panel))
		grid.add_child(tile)
	var sizes := HBoxContainer.new()
	sizes.alignment = BoxContainer.ALIGNMENT_CENTER
	sizes.add_theme_constant_override("separation", 10)
	sizes.add_child(UiKit.label("גודל המפה:", 22, UiKit.TEXT, 700))
	for sz in [["small", "קטנה"], ["medium", "בינונית"], ["large", "גדולה + ערפל"]]:
		var on: bool = profile.settings.get("map", "small") == sz[0]
		var b := UiKit.button(sz[1], UiKit.BUTTON_RED if on else UiKit.BUTTON_STEEL, 20)
		b.custom_minimum_size = Vector2(150, 50)
		b.pressed.connect(func():
			profile.settings["map"] = sz[0]
			Sfx.play("click")
			_reopen(_world_panel))
		sizes.add_child(b)
	v.add_child(sizes)
	var go := UiKit.button("יוצאים לקרב!", UiKit.BUTTON_RED, 30)
	go.custom_minimum_size = Vector2(0, 70)
	go.pressed.connect(func():
		Sfx.play("horn")
		profile.save()
		app.start_battle(profile.settings.get("map", "small"), false, profile.settings.get("world", "meadow")))
	v.add_child(go)
	return f[0]


# ---------------------------------------------------------------- hero book

## The hero book: a two-page spread. Right page: the list of heroes and
## spells. Left page: everything about the chosen one - picture, what it
## does, its numbers, its power, a tip, and who it is strong / weak against.
func _book_panel(id: String) -> Control:
	var f := _frame("ספר הגיבורים", UiKit.GOLD, 980)
	var v: VBoxContainer = f[1]
	var spread := HBoxContainer.new()
	spread.add_theme_constant_override("separation", 18)
	v.add_child(spread)
	# list (first child = right side in a right-to-left layout)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(250, 470)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 2)
	scroll.add_child(list)
	spread.add_child(scroll)
	var how := UiKit.button("📜 איך משחקים", UiKit.BUTTON_RED if id == "how" else UiKit.BUTTON_STEEL, 17)
	how.custom_minimum_size = Vector2(230, 42)
	how.pressed.connect(func(): Sfx.play("click"); _reopen(func(): return _book_panel("how")))
	list.add_child(how)
	for k in BattleData.hero_ids() + BattleData.spell_ids():
		var b := UiKit.button(HeroTexts.name_of(k), UiKit.BUTTON_BRONZE if k == id else UiKit.BUTTON_STEEL, 17)
		b.custom_minimum_size = Vector2(230, 38)
		b.icon = Portraits.get_tex(k, 0)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 28)
		b.pressed.connect(func(): Sfx.play("click"); _reopen(func(): return _book_panel(k)))
		list.add_child(b)
	# a gold line down the middle of the book
	var spine := ColorRect.new()
	spine.color = Color(UiKit.GOLD_DARK.r, UiKit.GOLD_DARK.g, UiKit.GOLD_DARK.b, 0.6)
	spine.custom_minimum_size = Vector2(2, 0)
	spread.add_child(spine)
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 8)
	page.custom_minimum_size = Vector2(620, 0)
	spread.add_child(page)
	if id == "how":
		page.add_child(UiKit.title("איך משחקים", 36))
		for t in HeroTexts.HOW_TO_PLAY:
			page.add_child(UiKit.illuminated(t, 18, 610))
		return f[0]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 14)
	var pic := TextureRect.new()
	pic.texture = Portraits.get_tex(id, 0)
	pic.custom_minimum_size = Vector2(150, 150)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if pic.texture == null:
		var card := BattleCard.new()
		card.setup(0, id)
		card.key_hint = ""
		head.add_child(card)
	else:
		head.add_child(pic)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UiKit.title(HeroTexts.name_of(id), 40))
	var d := BattleData.card(id)
	hv.add_child(UiKit.label("מחיר: %d אנרגיה%s" % [int(d.get("cost", 0)), " · קלף קסם" if BattleData.is_spell(id) else ""], 18, UiKit.TEXT_SOFT, 700))
	if not profile.available_cards().has(id) and id != "king":
		hv.add_child(UiKit.label("🔒 " + _unlock_building(id), 17, UiKit.ACCENT, 700))
	head.add_child(hv)
	page.add_child(head)
	page.add_child(UiKit.illuminated(HeroTexts.role_of(id), 20, 610))
	if not BattleData.is_spell(id):
		var grid := GridContainer.new()
		grid.columns = 4
		grid.add_theme_constant_override("h_separation", 18)
		var stats := [["❤ חיים", int(d.get("hp", 0)), 2400.0], ["⚔ נזק למכה", int(d.get("dmg", 0)), 220.0],
			["➶ טווח", d.get("range", 1.2), 7.0], ["👣 מהירות", d.get("speed", 0), 2.6]]
		if d.get("heal", 0) > 0:
			stats[1] = ["✚ ריפוי", int(d["heal"]), 60.0]
		for st in stats:
			var a := UiKit.label(st[0], 17, UiKit.TEXT, 700)
			a.autowrap_mode = TextServer.AUTOWRAP_OFF
			grid.add_child(a)
			var bar := ProgressBar.new()
			bar.show_percentage = false
			bar.custom_minimum_size = Vector2(120, 14)
			bar.max_value = 1.0
			bar.step = 0.01
			bar.value = clampf(float(st[1]) / st[2], 0.05, 1.0)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			grid.add_child(bar)
		page.add_child(grid)
		var ab: Dictionary = d.get("ability", {})
		if not ab.is_empty():
			page.add_child(UiKit.label("כוח מיוחד: %s · %d אנרגיה · נטען תוך %d תורות" % [HeroTexts.ability_name(ab["id"]), int(ab.get("cost", 0)),
				ceili(float(ab.get("cooldown", 10)) / BattleScreen.TURN_SECONDS)], 20, UiKit.ACCENT, 700))
			page.add_child(UiKit.label(HeroTexts.ability_desc(ab["id"]), 18, UiKit.TEXT))
	var tip: Array = HeroTexts.TIPS.get(id, ["", "", ""])
	if tip[0] != "":
		page.add_child(UiKit.illuminated("עצה: " + tip[0], 18, 610))
	if tip[1] != "" or tip[2] != "":
		var sw := VBoxContainer.new()
		sw.add_theme_constant_override("separation", 30)
		if tip[1] != "":
			sw.add_child(UiKit.label("✔ חזק נגד: " + tip[1], 17, UiKit.GOOD, 700))
		if tip[2] != "":
			sw.add_child(UiKit.label("✕ חלש נגד: " + tip[2], 17, UiKit.ACCENT, 700))
		page.add_child(sw)
	if not BattleData.is_spell(id):
		page.add_child(UiKit.label("\"%s\"" % HeroTexts.random_line(id), 18, UiKit.TEXT_SOFT))
	return f[0]


# ---------------------------------------------------------------- settings

func _settings_panel() -> Control:
	var f := _frame("הגדרות")
	var v: VBoxContainer = f[1]
	for s in [["מוזיקה", Music.volume, func(x): Music.set_volume(x)], ["צלילים וקולות", Sfx.volume, func(x): Sfx.volume = x; Voice.volume = x]]:
		v.add_child(UiKit.label(s[0], 20))
		var sl := HSlider.new()
		sl.min_value = 0.0
		sl.max_value = 1.0
		sl.step = 0.05
		sl.value = s[1]
		sl.custom_minimum_size = Vector2(400, 30)
		sl.value_changed.connect(func(x):
			s[2].call(x)
			app.save_settings())
		v.add_child(sl)
	v.add_child(UiKit.label("סצנות קרב בזירה", 20))
	var srow := HBoxContainer.new()
	srow.alignment = BoxContainer.ALIGNMENT_CENTER
	for m in [["always", "בכל תור"], ["important", "רק חשובות"], ["never", "אף פעם"]]:
		var on: bool = profile.settings.get("scenes", "always") == m[0]
		var sb := UiKit.button(m[1], UiKit.BUTTON_RED if on else UiKit.BUTTON_STEEL, 17)
		sb.custom_minimum_size = Vector2(130, 46)
		sb.pressed.connect(func():
			profile.settings["scenes"] = m[0]
			profile.save()
			Sfx.play("click")
			_reopen(_settings_panel))
		srow.add_child(sb)
	v.add_child(srow)
	var tut := UiKit.button("לשחק שוב את קרב ההדרכה", UiKit.BUTTON_STEEL, 18)
	tut.pressed.connect(func(): app.start_tutorial())
	v.add_child(tut)
	v.add_child(UiKit.label("ניצחונות %d · הפסדים %d" % [profile.wins, profile.losses], 16, UiKit.TEXT_SOFT))
	var reset := UiKit.button("למחוק את כל ההתקדמות", UiKit.BUTTON_RED, 16)
	reset.pressed.connect(func():
		if reset.text != "בטוחים? לחצו שוב":
			reset.text = "בטוחים? לחצו שוב"
			return
		app.profile = Profile.new_profile()
		app.profile.tutorial_done = true
		app.profile.save()
		app.go_base())
	v.add_child(reset)
	return f[0]
