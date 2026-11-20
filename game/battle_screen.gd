class_name BattleScreen
extends Node
## Runs one battle in SIMULTANEOUS TURNS:
##   1. PLAN   - time stands still. The player gives orders: walk / attack,
##               cards (heroes and spells) and powers. Cards and powers are
##               only planned (markers on the map); energy is reserved.
##   2. ACTION - "בצע!" : the computer plans its turn at the same moment
##               (without seeing the player's plan), all plans start together
##               and the world runs for TURN_SECONDS. Faster / skip buttons.
##               A big moment (power, tower falls...) gets a short cinematic.
##   3. back to PLAN with a summary of what happened in the turn.
## Heroes without orders fight enemies that come close by themselves.
##
## Controls (plan phase):
##   left click a hero / drag a box     choose heroes (Shift = add)
##   right click ground / enemy         walk there / attack it
##   1-8 or click a card                plan a hero / pick a spell, then click the map
##   Q or a power button                plan the chosen hero's power
##   Space / Enter                      execute the turn       A  whole army   Esc  cancel

signal finished(result: Dictionary)

const TURN_SECONDS := 5.0
const SCENE_SECONDS := 1.8

enum Phase { PLAN, ACTION, SCENE, ARENA, OVER }

var battle: Battle
var view: BattleView
var hud: BattleHud
var camera_rig: CameraRig
var ai: BattleAI
var phase: int = Phase.PLAN
var selected: Array = []
var turn := 1
var speed := 1.0
var tutorial: Node = null           ## optional TutorialGuide watching the battle
var autoplay: BattleAI = null       ## the computer plays the Sun too (screenshots / demo)
## The player's planned cards and powers for this turn:
## { "kind": "card"|"ability", "idx"|"unit": ..., "pos": Vector2, "cost": float, "marker": Node3D }
var plan: Array = []

var _chosen_card := -1
var _target_unit := -1
var _drag_from := Vector2.ZERO
var _dragging := false
var _size := "small"
var _stats := { "kills": 0, "lost": 0, "structures": 0, "spells": 0, "powers": 0, "monsters": 0, "treasures": 0 }
var _turn_stats := {}
var _turn_left := 0.0
var _scene_used := false
var _scene_left := 0.0
var _talk_cooldown := 0.0
var _turns_done := 0
var arena: BattleArena
var scene_mode := "always"          ## arena scenes: always (once a turn) / important / never
var _arena_used := false


func start(size: String, deck: Array, levels: Dictionary, ai_deck: Array, ai_level: int, ai_levels: Dictionary = {}, biome: String = "meadow") -> void:
	_size = size
	battle = Battle.create(size, [deck, ai_deck], [levels, ai_levels], randi() % 1000, biome)
	ai = BattleAI.new(1, ai_level)
	view = BattleView.new()
	view.camera_rig = camera_rig
	add_child(view)
	view.setup(battle, 0)
	arena = BattleArena.new()
	add_child(arena)
	hud = BattleHud.new()
	add_child(hud)
	hud.setup(battle, 0)
	hud.card_pressed.connect(_on_card)
	hud.ability_pressed.connect(_on_ability)
	hud.upgrade_pressed.connect(func():
		if phase == Phase.PLAN and battle.upgrade_palace(0):
			hud.flash("הארמון שודרג!", UiKit.GOLD)
			Sfx.play("upgrade"))
	hud.execute_pressed.connect(execute_turn)
	hud.speed_pressed.connect(func():
		speed = 2.5 if speed == 1.0 else 1.0
		Sfx.play("click"))
	hud.skip_pressed.connect(skip_turn)
	hud.clear_plan_pressed.connect(clear_plan)
	hud.exit_pressed.connect(func(): _finish(1, true))
	hud.help_pressed.connect(func(): hud.show_help())
	camera_rig.drag_buttons = [MOUSE_BUTTON_MIDDLE]
	camera_rig.edge_scroll = true
	camera_rig.set_limits(battle.w, battle.h)
	camera_rig.distance = 17.0 if size == "small" else 19.0
	var gate: Vector2i = battle.map["palaces"][0]["gate"]
	camera_rig.look_at_point(view.to_world(Vector2(gate) + Vector2(0, 2.5)), false)
	hud.flash("תור 1 · תכננו את המהלך!", UiKit.GOLD, 1.2)
	Sfx.play("horn")
	Music.play("plan")
	_begin_plan()


func _begin_plan() -> void:
	phase = Phase.PLAN
	if turn % 3 == 2 or _king_hurt_new():
		_taunt()
	speed = 1.0
	hud.set_phase(phase, turn, 0.0)
	hud.set_hint("בחרו גיבורים ושלחו אותם בלחצן ימני, הוסיפו קלפים וכוחות, ואז לחצו על 'בצע!'", 0.0)
	Music.play("plan")


## Starts the action: the computer plans now, then both plans begin together.
func execute_turn() -> void:
	if phase != Phase.PLAN or battle.is_over():
		return
	_cancel()
	ai.plan_turn(battle)
	if autoplay != null:
		autoplay.plan_turn(battle)
	for p in plan:
		var ok := false
		if p["kind"] == "card":
			ok = battle.play_card(0, p["idx"], p["pos"])
			if ok and not BattleData.is_spell(battle.cards[0][p["idx"]]["id"]):
				var new_id: int = battle.cards[0][p["idx"]]["unit"]
				if p.has("goto"):
					battle.order_move([new_id], p["goto"])
		else:
			ok = battle.cast_ability(p["unit"], p["pos"])
			var u := battle.unit(p["unit"])
			if ok and u != null:
				_say(u, 1.0)
		if is_instance_valid(p["marker"]):
			p["marker"].queue_free()
	plan.clear()
	_turn_stats = { "kills": 0, "lost": 0, "energy": 0.0, "damage_done": 0.0, "damage_taken": 0.0, "structures": [] }
	_turn_left = TURN_SECONDS
	_scene_used = false
	_arena_used = false
	phase = Phase.ACTION
	hud.set_hint("")
	Sfx.play("horn", 0.6)
	Music.play("battle")


## Fast-forward to the end of the turn at once.
func skip_turn() -> void:
	if phase == Phase.ARENA:
		arena.skip()
		return
	if phase != Phase.ACTION and phase != Phase.SCENE:
		return
	_end_scene()
	var t := 0.0
	var all := []
	while t < _turn_left and not battle.is_over():
		battle.step(Battle.TICK)
		t += Battle.TICK
		all += battle.take_events()
	_turn_left = 0.0
	# only show what matters, not every single hit
	var important := all.filter(func(e): return e["type"] in ["death", "breach", "upgrade", "game_over", "spawn"])
	_count(all)
	view.play_events(important)
	_react(important)
	if phase != Phase.OVER:
		_end_turn()


func _end_turn() -> void:
	_turns_done += 1
	turn += 1
	hud.show_turn_summary(turn - 1, _turn_stats, battle)
	if tutorial == null or turn > 2:
		hud.flash("תור %d" % turn, UiKit.GOLD, 0.6)
	_begin_plan()
	if autoplay != null:
		get_tree().create_timer(0.4).timeout.connect(execute_turn)


func clear_plan() -> void:
	for p in plan:
		if is_instance_valid(p["marker"]):
			p["marker"].queue_free()
	plan.clear()
	Sfx.play("click")


## Energy the player can still spend this turn (planned cards are reserved).
func free_energy() -> float:
	var e: float = battle.energy[0]
	for p in plan:
		e -= p["cost"]
	return e


func is_planned_card(idx: int) -> bool:
	return plan.any(func(p): return p["kind"] == "card" and p["idx"] == idx)


func is_planned_unit(id: int) -> bool:
	return plan.any(func(p): return p["kind"] == "ability" and p["unit"] == id)


func _process(delta: float) -> void:
	if battle == null:
		return
	_talk_cooldown -= delta
	match phase:
		Phase.ACTION:
			var dt := minf(delta * speed, 0.25)
			_run(dt)
			_turn_left -= dt
			if _turn_left <= 0.0 and phase == Phase.ACTION:
				_end_turn()
		Phase.SCENE:
			_run(delta * 0.3)
			_scene_left -= delta
			if _scene_left <= 0.0:
				_end_scene()
		_:
			# nothing moves, but things like palace upgrades still need showing
			var events := battle.take_events()
			if not events.is_empty():
				view.play_events(events)
				_react(events)
	selected = selected.filter(func(id): return battle.unit(id) != null)
	_update_target_preview()
	hud.refresh(self)
	if tutorial != null:
		tutorial.update(self)


func _run(dt: float) -> void:
	battle.step(dt)
	var events := battle.take_events()
	_count(events)
	view.play_events(events)
	_react(events)


func _count(events: Array) -> void:
	if _turn_stats.is_empty():
		return
	for e in events:
		match e["type"]:
			"death":
				if e["team"] == 1:
					_turn_stats["kills"] += 1
				else:
					_turn_stats["lost"] += 1
				if e["kind"] in ["tower", "gate"]:
					_turn_stats["structures"].append([e["kind"], e["team"]])
			"energy":
				if e["team"] == 0:
					_turn_stats["energy"] += e["amount"]
			"damage":
				var u := battle.unit(e["id"])
				if u != null:
					_turn_stats["damage_taken" if u.team == 0 else "damage_done"] += e["amount"]


# ------------------------------------------------------------------ big moments

## A short cinematic: the camera swoops in, time slows down, a title appears.
func _maybe_scene(pos: Vector2, title: String) -> void:
	if _scene_used or phase != Phase.ACTION or speed > 1.0:
		return
	_scene_used = true
	phase = Phase.SCENE
	_scene_left = SCENE_SECONDS
	camera_rig.focus(view.to_world(pos), 12.0, 0.4)
	hud.cinematic(true, title)
	if tutorial != null:
		tutorial.visible = false


## A hero defeated another hero: cut to the arena and show the duel.
func _maybe_arena(e: Dictionary) -> void:
	if _arena_used or phase != Phase.ACTION or scene_mode == "never" or e.get("killer", "") == "":
		return
	var killer := battle.unit(e.get("killer_id", -1))
	if killer == null or killer.structure or e["kind"] == "king":
		return
	if not (battle.is_visible(0, e["pos"]) or e["team"] == 0 or killer.team == 0):
		return
	if scene_mode == "important":
		var big := ["queen", "dragon", "giant", "ballista", "knight", "assassin"]
		if not (big.has(e["kind"]) or big.has(killer.kind) or e["team"] == Battle.NEUTRAL):
			return
	_arena_used = true
	phase = Phase.ARENA
	Music.play("battle")
	await arena.play(e, battle.world, killer.team, hud)
	camera_rig.make_current()
	await hud.fade(0.0, 0.3)
	if phase == Phase.ARENA:
		phase = Phase.ACTION


func _end_scene() -> void:
	if phase != Phase.SCENE:
		return
	phase = Phase.ACTION
	camera_rig.reset_view(true)
	hud.cinematic(false, "")
	if tutorial != null:
		tutorial.visible = true


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
					Sfx.play("crash")
					_maybe_scene(e["pos"], "המגדל נופל!")
					hud.flash("מגדל נפל!" if e["team"] == 1 else "איבדנו מגדל!", Color(1, 0.85, 0.4) if e["team"] == 1 else Color(1, 0.4, 0.3))
					if e["team"] == 1:
						_stats["structures"] += 1
				elif e["kind"] == "gate":
					Sfx.play("crash")
					_maybe_scene(e["pos"], "השער נשבר!")
					hud.flash("השער נשבר! המלך חשוף!" if e["team"] == 1 else "השער שלנו נשבר!", Color(1, 0.85, 0.4) if e["team"] == 1 else Color(1, 0.4, 0.3))
					if e["team"] == 1:
						_stats["structures"] += 1
				elif e["kind"] != "wall":
					Sfx.play("poof", 0.5)
					_maybe_arena(e)
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
				if e["type"] == "ability":
					var who := battle.unit(e["id"])
					var title := HeroTexts.ability_name(e["ability"])
					if who != null:
						title = "%s: %s" % [HeroTexts.name_of(who.kind), title]
					_maybe_scene(e["pos"], title)
			"energy":
				if e["team"] == 0 and e["id"] >= 0:
					Sfx.play("coin", 0.25)
			"treasure":
				if e["team"] == 0:
					_stats["treasures"] += 1
				Sfx.play("chest")
				hud.flash("מצאתם אוצר! +4 אנרגיה" if e["team"] == 0 else "האויב מצא אוצר", UiKit.GOLD if e["team"] == 0 else Color(0.8, 0.6, 1.0), 0.8)
			"treasure_spawn":
				if e["id"] % 2 == 1:
					hud.flash("תיבות אוצר הופיעו במפה!", UiKit.GOLD, 0.8)
					Sfx.play("reward", 0.6)
			"monster_slain":
				if e["team"] == 0:
					_stats["monsters"] += 1
				Sfx.play("fanfare" if e["team"] == 0 else "crash", 0.5)
				hud.flash("הבסתם את %s! +6 אנרגיה" % BattleData.biomes()["monsters"][e["kind"]]["name"] if e["team"] == 0 else "האויב הביס מפלצת", UiKit.GOLD, 1.0)
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


var _king_hp_seen := -1.0


func _king_hurt_new() -> bool:
	var k := battle.king(1)
	if k == null:
		return false
	var hurt := _king_hp_seen >= 0.0 and k.hp < _king_hp_seen - 1.0
	_king_hp_seen = k.hp
	return hurt


## The enemy king shouts something at the player from his palace.
func _taunt() -> void:
	var k := battle.king(1)
	if k == null or not view.view(k.id):
		return
	var exposed := battle.king_exposed(1) or k.hp < k.max_hp
	var lines: Array = HeroTexts.TAUNTS_HURT if exposed else HeroTexts.TAUNTS
	var cam := get_viewport().get_camera_3d()
	var p := cam.unproject_position(view.view(k.id).global_position + Vector3(0, 2.4, 0))
	var vs := get_viewport().get_visible_rect().size
	# if the king is off screen, the bubble shows at the top of the screen
	if p.x < 0 or p.y < 0 or p.x > vs.x or p.y > vs.y:
		p = Vector2(vs.x * 0.5, 170)
	hud.speech(p, "👑 " + String(lines[randi() % lines.size()]))
	Voice.babble("king", 5)


## A hero says one of its funny lines (speech bubble + gibberish voice).
func _say(u: BUnit, chance: float = 0.3) -> void:
	if u == null or _talk_cooldown > 0.0 or randf() > chance:
		return
	var v := view.view(u.id)
	if v == null:
		return
	_talk_cooldown = 2.5
	var cam := get_viewport().get_camera_3d()
	hud.speech(cam.unproject_position(v.global_position + Vector3(0, 2.0, 0)), HeroTexts.random_line(u.kind))
	Voice.babble(u.kind)


func _finish(winner: int, quit: bool) -> void:
	if phase == Phase.OVER:
		return
	_end_scene()
	phase = Phase.OVER
	_chosen_card = -1
	_target_unit = -1
	view.hide_target_circle()
	if tutorial != null:
		tutorial.visible = false
	var won := winner == 0 and not quit
	if won:
		hud.flash("ניצחון!", UiKit.GOLD, 2.0)
		Sfx.play("fanfare")
	elif winner == 2:
		hud.flash("תיקו", UiKit.GOLD, 2.0)
	else:
		hud.flash("הפסד", Color(1, 0.45, 0.35), 2.0)
		Sfx.play("lose")
	var result := { "won": won, "draw": winner == 2, "quit": quit, "time": battle.time, "size": _size, "turns": turn,
		"bonus_gold": battle.bonus_gold[0], "world": battle.biome, "summons": battle.summons[0] }
	result.merge(_stats)
	await get_tree().create_timer(0.3 if quit else 2.8).timeout
	finished.emit(result)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if battle == null or phase == Phase.OVER:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER, KEY_KP_ENTER:
				if phase == Phase.PLAN:
					execute_turn()
				else:
					skip_turn()
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
					_plan_spell_at(view.ground_at_screen(event.position))
				elif _target_unit >= 0:
					_plan_ability_at(view.ground_at_screen(event.position))
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
			elif phase == Phase.PLAN:
				_order(event.position)
			else:
				hud.flash("פקודות נותנים רק בשלב התכנון", UiKit.GOLD, 0.7)
	elif event is InputEventMouseMotion and _dragging:
		hud.show_drag_box(Rect2(_drag_from, Vector2.ZERO).expand(event.position))


func _click_select(screen: Vector2, add: bool) -> void:
	var id := view.unit_at_screen(screen)
	var u := battle.unit(id) if id >= 0 else null
	if u != null and u.team == 0 and not u.structure:
		_select([id], add)
		_say(u, 0.25)
		Sfx.play("select", 0.6)
	elif u != null and u.team == 1:
		hud.show_unit_info(u)
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
	if selected.size() == 1:
		hud.show_unit_info(battle.unit(selected[0]))
	else:
		hud.show_unit_info(null)


func _order(screen: Vector2) -> void:
	var movers := selected.filter(func(id):
		var u := battle.unit(id)
		return u != null and u.speed > 0.0)
	if movers.is_empty():
		if not selected.is_empty():
			hud.flash("המלך לא יוצא מהארמון", UiKit.GOLD, 0.8)
		return
	var id := view.unit_at_screen(screen)
	var t := battle.unit(id) if id >= 0 else null
	if t != null and t.team == 1 and battle.can_target(0, t):
		battle.order_attack(movers, id)
		view.order_marker(t.pos, true)
		Sfx.play("order")
	else:
		if t != null and t.kind == "king" and t.team == 1:
			hud.flash("המלך מוגן! קודם צריך לשבור את השער או מגדל", Color(1, 0.7, 0.4), 1.2)
		var p := view.ground_at_screen(screen)
		if not battle.in_bounds(p):
			return
		battle.order_move(movers, p)
		view.order_marker(p, false)
		Sfx.play("order")
		if randf() < 0.3:
			_say(battle.unit(movers[0]), 0.5)


func _on_card(idx: int) -> void:
	if phase != Phase.PLAN:
		hud.flash("את הקלפים בוחרים בשלב התכנון", UiKit.GOLD, 0.7)
		return
	if idx < 0 or idx >= battle.cards[0].size():
		return
	var id: String = battle.cards[0][idx]["id"]
	# clicking a planned card takes it back
	for p in plan:
		if p["kind"] == "card" and p["idx"] == idx:
			if is_instance_valid(p["marker"]):
				p["marker"].queue_free()
			plan.erase(p)
			Sfx.play("click")
			return
	var wait := battle.card_wait(0, idx)
	if wait > 0.0:
		hud.flash("הקלף %s יהיה מוכן בעוד %d תורות" % [HeroTexts.name_of(id), ceili(wait / TURN_SECONDS)], UiKit.GOLD, 0.8)
		return
	if free_energy() < battle.card_cost(id):
		hud.flash("אין מספיק אנרגיה. כורים במכרות מביאים עוד!", Style.CRYSTAL, 0.9)
		Sfx.play("deny")
		return
	if BattleData.is_spell(id):
		_target_unit = -1
		_chosen_card = -1 if _chosen_card == idx else idx
		if _chosen_card >= 0:
			hud.set_hint("לחצו על המפה כדי לכוון את %s · לחצן ימני מבטל" % HeroTexts.name_of(id))
		return
	# a hero: planned to appear at the gate when the turn starts
	var spawn: Vector2i = battle.map["palaces"][0]["spawn"]
	var marker := view.plan_marker(Vector2(spawn), 0.6, Style.team(0)["ui"], "זימון: %s" % HeroTexts.name_of(id))
	plan.append({ "kind": "card", "idx": idx, "pos": Vector2.ZERO, "cost": battle.card_cost(id), "marker": marker })
	Sfx.play("summon", 0.5)


func _on_ability(unit_id: int) -> void:
	if phase != Phase.PLAN:
		hud.flash("את הכוחות בוחרים בשלב התכנון", UiKit.GOLD, 0.7)
		return
	var u := battle.unit(unit_id)
	if u == null:
		return
	var ab := battle.ability_of(u)
	if ab.is_empty():
		return
	for p in plan:
		if p["kind"] == "ability" and p["unit"] == unit_id:
			if is_instance_valid(p["marker"]):
				p["marker"].queue_free()
			plan.erase(p)
			Sfx.play("click")
			return
	if battle.time < u.ability_ready_at:
		hud.flash("הכוח יהיה מוכן בעוד %d תורות" % ceili((u.ability_ready_at - battle.time) / TURN_SECONDS), UiKit.GOLD, 0.8)
		return
	if free_energy() < float(ab.get("cost", 0)):
		hud.flash("אין מספיק אנרגיה", Style.CRYSTAL, 0.7)
		Sfx.play("deny")
		return
	if ab.get("self", false):
		_add_ability_plan(u, u.pos)
		return
	_chosen_card = -1
	_target_unit = unit_id
	hud.set_hint("%s: לחצו על המטרה · לחצן ימני מבטל" % HeroTexts.ability_name(ab["id"]))


func _add_ability_plan(u: BUnit, pos: Vector2) -> void:
	var ab := battle.ability_of(u)
	var marker := view.plan_marker(pos, float(ab.get("radius", 1.0)), Color(1.0, 0.75, 0.3), HeroTexts.ability_name(ab["id"]))
	plan.append({ "kind": "ability", "unit": u.id, "pos": pos, "cost": float(ab.get("cost", 0)), "marker": marker })
	Sfx.play("power", 0.4)


func _plan_spell_at(p: Vector2) -> void:
	var idx := _chosen_card
	var sp := BattleData.spell(battle.cards[0][idx]["id"])
	if not battle.in_bounds(p) or not battle.is_visible(0, p):
		hud.flash("אי אפשר להטיל קסם לשם", Color(1, 0.6, 0.4), 0.6)
		Sfx.play("deny")
		return
	var marker := view.plan_marker(p, float(sp.get("radius", 1.0)), Color(0.75, 0.55, 1.0), HeroTexts.name_of(battle.cards[0][idx]["id"]))
	plan.append({ "kind": "card", "idx": idx, "pos": p, "cost": battle.card_cost(battle.cards[0][idx]["id"]), "marker": marker })
	_chosen_card = -1
	hud.set_hint("")
	Sfx.play("power", 0.4)


func _plan_ability_at(p: Vector2) -> void:
	var u := battle.unit(_target_unit)
	if u == null:
		_cancel()
		return
	var ab := battle.ability_of(u)
	if u.pos.distance_to(p) > float(ab.get("range", 5)):
		hud.flash("רחוק מדי. הטווח מסומן בעיגול", Color(1, 0.6, 0.4), 0.8)
		Sfx.play("deny")
		return
	if ab["type"] == "dash" and not battle._passable_for(u, Vector2i(roundi(p.x), roundi(p.y))):
		hud.flash("אי אפשר לקפוץ לשם", Color(1, 0.6, 0.4), 0.6)
		return
	_add_ability_plan(u, p)
	_say(u, 0.6)
	_target_unit = -1
	hud.set_hint("")


func _cancel() -> void:
	_chosen_card = -1
	_target_unit = -1
	if phase == Phase.PLAN:
		hud.set_hint("")
	view.hide_target_circle()
	view.hide_range_circle()


func _update_target_preview() -> void:
	var mouse := get_viewport().get_mouse_position()
	if _chosen_card >= 0:
		var sp := BattleData.spell(battle.cards[0][_chosen_card]["id"])
		view.show_target_circle(view.ground_at_screen(mouse), float(sp.get("radius", 1.0)), Color(0.8, 0.6, 1.0))
		view.hide_range_circle()
	elif _target_unit >= 0 and battle.unit(_target_unit) != null:
		var u := battle.unit(_target_unit)
		var ab := battle.ability_of(u)
		var p := view.ground_at_screen(mouse)
		var ok := u.pos.distance_to(p) <= float(ab.get("range", 5))
		view.show_target_circle(p, float(ab.get("radius", 1.0)), Color(1.0, 0.85, 0.4) if ok else Color(1, 0.25, 0.2))
		view.show_range_circle(u.pos, float(ab.get("range", 5)))
	else:
		view.hide_target_circle()
		view.hide_range_circle()
