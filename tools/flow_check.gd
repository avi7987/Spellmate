extends SceneTree
## Plays through the whole game like a person would and prints each step.
## Any SCRIPT ERROR in the output = something broke.
## xvfb-run -a godot --rendering-driver opengl3 --script res://tools/flow_check.gd -- [shots_dir]

var app: Node
var dir := ""


func _shot(name: String) -> void:
	if dir != "":
		root.get_texture().get_image().save_png("%s/%s.png" % [dir, name])


func _bs() -> BattleScreen:
	for n in app.get_children():
		if n is BattleScreen:
			return n
	return null


func _base() -> BaseScreen:
	for n in app.get_children():
		if n is BaseScreen:
			return n
	return null


func _select_enemy(bs: BattleScreen) -> void:
	bs.hud.show_unit_info(bs.battle.heroes_of(0)[0] if not bs.battle.heroes_of(0).is_empty() else bs.battle.king(0))


func _wait(s: float) -> void:
	await create_timer(s).timeout


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	dir = args[0] if args.size() > 0 else ""
	DisplayServer.window_set_size(Vector2i(1280, 800))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.json"))
	app = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await _wait(3.0)
	var bs := _bs()
	print("1 tutorial battle started: ", bs != null, " guide: ", bs.tutorial != null)
	_shot("01_tutorial")
	var cam := root.get_camera_3d()
	# chess-like: click a hero, then click one of its lit squares (real screen clicks)
	var army := bs.battle.heroes_of(0).filter(func(u): return u.role() != "miner")
	var hero: BUnit = army[0]
	bs._board_click(cam.unproject_position(bs.view.view(hero.id).global_position + Vector3(0, 0.5, 0)))
	print("2 selected ", bs.selected, " = ", hero.id)
	await _wait(0.3)
	var goal := hero.cell() + Vector2i(0, 2)
	print("2b lit squares ", bs.view.reach_now.size(), " goal lit: ", bs.view.reach_now.has(goal))
	_shot("01b_lit_squares")
	bs._board_click(cam.unproject_position(bs.view.to_world(Vector2(goal))))
	print("3 ordered: ", hero.order, " to ", hero.order_pos)
	await _wait(0.5)
	bs.battle.energy[0] = 20
	bs._on_card(1)   # archer (planned)
	print("4 archer planned: ", bs.is_planned_card(1), " free energy ", bs.free_energy())
	bs._on_card(6)   # fire bomb
	bs._plan_spell_at(Vector2(7, 14))
	print("5 fire bomb planned: ", bs.is_planned_card(6))
	var queen: BUnit = bs.battle.units.filter(func(u): return u.kind == "queen" and u.team == 0)[0]
	bs._on_ability(queen.id)
	bs._plan_ability_at(queen.pos + Vector2(0, 3))
	print("6 queen power planned: ", bs.is_planned_unit(queen.id))
	_shot("02_plan")
	bs.execute_turn()
	print("7 executed: phase ", bs.phase, " archer on field ", bs.battle.cards[0][1]["unit"] >= 0, " spell cooldown ", bs.battle.card_wait(0, 6) > 0.0)
	await _wait(1.0)
	_shot("03_action")
	await _wait(5.5)
	print("8 next turn: ", bs.turn, " phase ", bs.phase)
	_shot("03b_summary")
	bs.execute_turn()
	await _wait(0.5)
	bs.skip_turn()
	print("9 skipped to turn ", bs.turn)
	_select_enemy(bs)
	_shot("03c_info")
	# win: break the gate and checkmate the king
	bs.battle._damage(bs.battle.gate(1), 1e9, null)
	bs.battle._win(0, "mate")
	await _wait(3.5)
	_shot("04_results")
	var panel: ResultsPanel = null
	for n in app.find_children("*", "ResultsPanel", true, false):
		panel = n
	print("10 results panel: ", panel != null, " gold ", app.profile.gold, " trophies ", app.profile.trophies, " chests ", app.profile.chests)
	panel.closed.emit()
	await _wait(3.0)
	var base := _base()
	print("11 base: ", base != null, " tutorial_done ", app.profile.tutorial_done)
	_shot("05_base")
	base._open_chest(0)
	await _wait(2.5)
	_shot("06_chest")
	app.profile.gold = 2000
	base._open(base._building_panel("mage_tower"))
	await _wait(0.5)
	print("12 build mage tower: ", app.profile.build("mage_tower"))
	base._rebuild_buildings()
	base._open(base._heroes_panel())
	await _wait(0.5)
	app.profile.add_xp("queen", 100)
	print("13 upgrade queen: ", app.profile.upgrade_hero("queen"))
	base._deck_slot = 0
	base._open(base._deck_panel())
	print("14 deck swap: ", app.profile.set_deck_card(0, "queen"), " ", app.profile.deck)
	await _wait(0.5)
	_shot("07_deck")
	base._open(base._settings_panel())
	await _wait(0.3)
	app.start_battle("large")
	await _wait(4.0)
	print("15 large battle with fog: ", _bs() != null and _bs().battle.map["fog"])
	_shot("08_large")
	_bs()._finish(1, true)
	await _wait(1.0)
	print("16 quit -> results")
	print("DONE")
	quit()
