class_name BattleScreen
extends Node
## Runs one real-time battle on screen: steps the Battle, lets the computer
## think, draws everything (BattleView + BattleHud) and turns the player's
## mouse and keys into orders.
##
## Controls:
##   left click a hero / drag a box     choose heroes (Shift = add)
##   right click ground / enemy         walk there / attack it
##   1-8 or click a card                summon a hero / pick a spell, then click the map
##   Q or a power button                the chosen hero's special power
##   Space                              pause (orders still work while paused)
##   A                                  choose the whole army      Esc  cancel

signal finished(result: Dictionary)

var battle: Battle
var view: BattleView
var hud: BattleHud
var camera_rig: CameraRig
var ai: BattleAI
var paused := false
var selected: Array = []
var tutorial: Node = null           ## optional TutorialGuide watching the battle
var autoplay: BattleAI = null       ## the computer plays the Sun too (screenshots / demo)

var _chosen_card := -1
var _target_unit := -1
var _drag_from := Vector2.ZERO
var _dragging := false
var _over := false
var _size := "small"
var _stats := { "kills": 0, "lost": 0, "structures": 0, "spells": 0, "powers": 0 }
var _talk_cooldown := 0.0


func start(size: String, deck: Array, levels: Dictionary, ai_deck: Array, ai_level: int, ai_levels: Dictionary = {}) -> void:
	_size = size
	battle = Battle.create(size, [deck, ai_deck], [levels, ai_levels], randi() % 1000)
	ai = BattleAI.new(1, ai_level)
	view = BattleView.new()
	view.camera_rig = camera_rig
	add_child(view)
	view.setup(battle, 0)
	hud = BattleHud.new()
	add_child(hud)
	hud.setup(battle, 0)
	hud.card_pressed.connect(_on_card)
	hud.ability_pressed.connect(_on_ability)
	hud.upgrade_pressed.connect(func():
		if battle.upgrade_palace(0):
			hud.flash("הארמון שודרג!", UiKit.GOLD)
			Sfx.play("upgrade"))
	hud.pause_pressed.connect(toggle_pause)
	hud.exit_pressed.connect(func(): _finish(1, true))
	camera_rig.drag_buttons = [MOUSE_BUTTON_MIDDLE]
	camera_rig.edge_scroll = true
	camera_rig.set_limits(battle.w, battle.h)
	camera_rig.distance = 17.0 if size == "small" else 19.0
	var gate: Vector2i = battle.map["palaces"][0]["gate"]
	camera_rig.look_at_point(view.to_world(Vector2(gate) + Vector2(0, 2.5)), false)
	hud.flash("לקרב!", UiKit.GOLD, 0.8)
	hud.set_hint("גרור ריבוע כדי לבחור גיבורים • לחצן ימני = לשלוח • רווח = הפסקה", 10.0)
	Sfx.play("horn")
	Music.play("battle")


func toggle_pause() -> void:
	if _over:
		return
	paused = not paused
	Sfx.play("click")


func _process(delta: float) -> void:
	if battle == null:
		return
	_talk_cooldown -= delta
	if not paused and not _over:
		ai.think(battle)
		if autoplay != null:
			autoplay.think(battle)
		battle.step(minf(delta, 0.1))
	var events := battle.take_events()
	view.play_events(events)
	_react(events)
	selected = selected.filter(func(id): return battle.unit(id) != null)
	_update_target_preview()
	hud.refresh(selected, _chosen_card, paused)
	if tutorial != null:
		tutorial.update(self)


## Messages, sounds and voices for what just happened.
func _react(events: Array) -> void:
	for e in events:
		match e["type"]:
			"death":
				if e["team"] == 1:
					_stats["kills"] += 1
				else:
					_stats["lost"] += 1
				if e["kind"] == "tower":
					hud.flash("מגדל נפל!" if e["team"] == 1 else "איבדנו מגדל!", Color(1, 0.85, 0.4) if e["team"] == 1 else Color(1, 0.4, 0.3))
					Sfx.play("crash")
					if e["team"] == 1:
						_stats["structures"] += 1
				elif e["kind"] == "gate":
					hud.flash("השער נשבר! המלך חשוף!" if e["team"] == 1 else "השער שלנו נשבר!", Color(1, 0.85, 0.4) if e["team"] == 1 else Color(1, 0.4, 0.3))
					Sfx.play("crash")
					if e["team"] == 1:
						_stats["structures"] += 1
				elif e["kind"] != "wall":
					Sfx.play("poof", 0.5)
			"attack":
				var a := battle.unit(e["id"])
				if a != null and (a.team == 0 or battle.is_visible(0, a.pos)):
					Sfx.play(_attack_sound(a.kind), 0.35)
			"spawn":
				var u := battle.unit(e["id"])
				if u != null and u.team == 0 and not u.structure and battle.time > 0.5:
					Sfx.play("summon")
					_say(u, 1.0)
			"ability", "spell":
				Sfx.play(_power_sound(e))
				if e.get("team", 0) == 0:
					_stats["powers" if e["type"] == "ability" else "spells"] += 1
			"energy":
				if e["team"] == 0 and e["id"] >= 0:
					Sfx.play("coin", 0.25)
			"upgrade":
				if e["team"] == 1:
					hud.flash("האויב שדרג את הארמון", Color(0.8, 0.6, 1.0))
			"game_over":
				_finish(e["winner"], false)


func _attack_sound(kind: String) -> String:
	match kind:
		"archer", "tower", "ballista": return "bow"
		"queen", "ice_witch", "fire_mage", "healer", "dragon": return "zap"
	return "hit"


func _power_sound(e: Dictionary) -> String:
	var id: String = e.get("ability", e.get("card", ""))
	if id in ["frost_nova", "ice_bomb", "blizzard"]:
		return "ice"
	if id in ["meteor", "fire_bomb", "fire_breath", "ground_smash", "piercing_bolt"]:
		return "boom"
	if id in ["mass_heal", "heal_potion"]:
		return "heal"
	return "power"


## A hero says one of its funny lines (speech bubble + gibberish voice).
func _say(u: BUnit, chance: float = 0.3) -> void:
	if _talk_cooldown > 0.0 or randf() > chance:
		return
	var v := view.view(u.id)
	if v == null:
		return
	_talk_cooldown = 2.5
	var cam := get_viewport().get_camera_3d()
	hud.speech(cam.unproject_position(v.global_position + Vector3(0, 2.0, 0)), HeroTexts.random_line(u.kind))
	Voice.babble(u.kind)


func _finish(winner: int, quit: bool) -> void:
	if _over:
		return
	_over = true
	paused = false
	_chosen_card = -1
	_target_unit = -1
	view.hide_target_circle()
	var won := winner == 0 and not quit
	if tutorial != null:
		tutorial.visible = false
	if won:
		hud.flash("ניצחון!", UiKit.GOLD, 2.0)
		Sfx.play("fanfare")
	elif winner == 2:
		hud.flash("תיקו", UiKit.TEXT, 2.0)
	else:
		hud.flash("הפסד…", Color(1, 0.45, 0.35), 2.0)
		Sfx.play("lose")
	var result := { "won": won, "draw": winner == 2, "quit": quit, "time": battle.time, "size": _size }
	result.merge(_stats)
	await get_tree().create_timer(0.3 if quit else 2.8).timeout
	finished.emit(result)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if battle == null or _over:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_P:
				toggle_pause()
			KEY_ESCAPE:
				_cancel()
			KEY_Q:
				for id in selected:
					var u := battle.unit(id)
					if u != null and not battle.ability_of(u).is_empty():
						_on_ability(id)
						break
			KEY_A:
				if not event.ctrl_pressed:
					_select(battle.heroes_of(0).map(func(u): return u.id), false)
			_:
				if event.keycode >= KEY_1 and event.keycode <= KEY_8:
					_on_card(event.keycode - KEY_1)
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if _chosen_card >= 0:
					_play_spell_at(view.ground_at_screen(event.position))
				elif _target_unit >= 0:
					_cast_at(view.ground_at_screen(event.position))
				else:
					_dragging = true
					_drag_from = event.position
			elif _dragging:
				_dragging = false
				hud.hide_drag_box()
				var rect := Rect2(_drag_from, Vector2.ZERO).expand(event.position)
				if rect.size.length() > 10.0:
					_select(view.units_in_rect(rect), event.shift_pressed)
				else:
					_click_select(event.position, event.shift_pressed)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			if _chosen_card >= 0 or _target_unit >= 0:
				_cancel()
			else:
				_order(event.position)
	elif event is InputEventMouseMotion and _dragging:
		hud.show_drag_box(Rect2(_drag_from, Vector2.ZERO).expand(event.position))


func _click_select(screen: Vector2, add: bool) -> void:
	var id := view.unit_at_screen(screen)
	var u := battle.unit(id) if id >= 0 else null
	if u != null and u.team == 0 and not u.structure and u.kind != "king":
		_select([id], add)
		_say(u, 0.25)
		Sfx.play("select", 0.6)
	elif u != null and u.team == 0 and u.kind == "king" and not battle.ability_of(u).is_empty():
		_select([id], add)
	elif not add:
		_select([], false)


func _select(ids: Array, add: bool) -> void:
	if add:
		for id in ids:
			if not selected.has(id):
				selected.append(id)
	else:
		selected = ids.duplicate()
	view.set_selection(selected)


func _order(screen: Vector2) -> void:
	var movers := selected.filter(func(id):
		var u := battle.unit(id)
		return u != null and u.speed > 0.0)
	if movers.is_empty():
		return
	var id := view.unit_at_screen(screen)
	var t := battle.unit(id) if id >= 0 else null
	if t != null and t.team == 1 and battle.can_target(0, t):
		battle.order_attack(movers, id)
		view.order_marker(t.pos, true)
		Sfx.play("order")
	else:
		if t != null and t.kind == "king" and t.team == 1:
			hud.flash("המלך מוגן! שברו קודם את השער או מגדל", Color(1, 0.7, 0.4), 1.2)
		var p := view.ground_at_screen(screen)
		if not battle.in_bounds(p):
			return
		battle.order_move(movers, p)
		view.order_marker(p, false)
		Sfx.play("order")
		if randf() < 0.3:
			_say(battle.unit(movers[0]), 0.5)


func _on_card(idx: int) -> void:
	if idx < 0 or idx >= battle.cards[0].size():
		return
	var id: String = battle.cards[0][idx]["id"]
	var wait := battle.card_wait(0, idx)
	if wait < 0.0:
		hud.flash("%s כבר בקרב" % HeroTexts.name_of(id), UiKit.TEXT_SOFT, 0.6)
		return
	if wait > 0.0:
		hud.flash("עוד %d שניות" % ceili(wait), UiKit.TEXT_SOFT, 0.6)
		return
	if battle.energy[0] < battle.card_cost(id):
		hud.flash("אין מספיק אנרגיה - צריך כורים במכרות!", Style.CRYSTAL, 0.9)
		Sfx.play("deny")
		return
	if BattleData.is_spell(id):
		_target_unit = -1
		_chosen_card = -1 if _chosen_card == idx else idx
		if _chosen_card >= 0:
			hud.set_hint("לחץ על המפה כדי להטיל %s (לחצן ימני = ביטול)" % HeroTexts.name_of(id))
		return
	if battle.play_card(0, idx):
		var new_id := battle.cards[0][idx]["unit"] as int
		_select([new_id], false)


func _on_ability(unit_id: int) -> void:
	var u := battle.unit(unit_id)
	if u == null:
		return
	var ab := battle.ability_of(u)
	if ab.is_empty():
		return
	if battle.time < u.ability_ready_at:
		hud.flash("הכוח עוד נטען", UiKit.TEXT_SOFT, 0.6)
		return
	if battle.energy[0] < float(ab.get("cost", 0)):
		hud.flash("אין מספיק אנרגיה", Style.CRYSTAL, 0.7)
		Sfx.play("deny")
		return
	if ab.get("self", false):
		if battle.cast_ability(unit_id, u.pos):
			_say(u, 1.0)
		return
	_chosen_card = -1
	_target_unit = unit_id
	hud.set_hint("%s: לחץ על המטרה (לחצן ימני = ביטול)" % HeroTexts.ability_name(ab["id"]))


func _play_spell_at(p: Vector2) -> void:
	var idx := _chosen_card
	if battle.play_card(0, idx, p):
		_chosen_card = -1
		hud.set_hint("")
	else:
		hud.flash("אי אפשר להטיל לשם", Color(1, 0.6, 0.4), 0.6)
		Sfx.play("deny")


func _cast_at(p: Vector2) -> void:
	var u := battle.unit(_target_unit)
	if u == null:
		_cancel()
		return
	if battle.cast_ability(_target_unit, p):
		_say(u, 1.0)
		_target_unit = -1
		hud.set_hint("")
	else:
		hud.flash("רחוק מדי או חסום", Color(1, 0.6, 0.4), 0.6)
		Sfx.play("deny")


func _cancel() -> void:
	_chosen_card = -1
	_target_unit = -1
	hud.set_hint("")
	view.hide_target_circle()


func _update_target_preview() -> void:
	var mouse := get_viewport().get_mouse_position()
	if _chosen_card >= 0:
		var sp := BattleData.spell(battle.cards[0][_chosen_card]["id"])
		view.show_target_circle(view.ground_at_screen(mouse), float(sp.get("radius", 1.0)), Color(0.8, 0.6, 1.0))
	elif _target_unit >= 0 and battle.unit(_target_unit) != null:
		var u := battle.unit(_target_unit)
		var ab := battle.ability_of(u)
		var p := view.ground_at_screen(mouse)
		var ok := u.pos.distance_to(p) <= float(ab.get("range", 5))
		view.show_target_circle(p, float(ab.get("radius", 1.0)), Color(1.0, 0.85, 0.4) if ok else Color(1, 0.25, 0.2))
	else:
		view.hide_target_circle()
