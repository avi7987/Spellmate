extends SceneTree
## Runs the real game and saves a screenshot after some seconds.
## xvfb-run -a godot --rendering-driver opengl3 --script res://tools/app_shot.gd -- out.png 6 [--battle small] [--autoplay] [--base] [speed=3] [select] [cast=fire_bomb wait=0.6] [--mode crown] [panel=heroes|deck|chests|building:mage_tower]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0]
	var secs := float(args[1])
	DisplayServer.window_set_size(Vector2i(1280, 800))
	for a in args:
		if a.begins_with("speed="):
			Engine.time_scale = float(a.substr(6))
		if a == "fresh":
			DirAccess.remove_absolute(ProjectSettings.globalize_path("user://profile.json"))
		if a == "rich":
			var p := Profile.new_profile()
			p.gold = 3000
			p.trophies = 700
			p.tutorial_done = true
			p.chests = ["gold", "silver", "wood"]
			p.build("mage_tower")
			p.build("barracks")
			p.decorations = ["well", "market"]
			if args.has("dragon"):
				p.build("dragon_roost")
				p.deck[1] = "dragon"
			p.save()
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await create_timer(secs * Engine.time_scale).timeout
	for a in args:
		if a == "select":
			for n in app.get_children():
				if n is BattleScreen:
					# one hero: its squares for this turn light up
					var hs: Array = n.battle.heroes_of(0).filter(func(u): return u.role() != "miner")
					n._select([hs[0].id], false)
		if a.begins_with("cast="):
			# show a spell card's animation in front of the Sun's palace (screenshot after `wait=`)
			for n in app.get_children():
				if n is BattleScreen:
					var b: Battle = n.battle
					b.energy[0] = 20
					var id := a.substr(5)
					b.cards[0][0]["id"] = id
					var gate: Vector2i = b.map["palaces"][0]["gate"]
					b.play_card(0, 0, Vector2(gate) + Vector2(0, 3))
		if a.begins_with("wait="):
			await create_timer(float(a.substr(5)) * Engine.time_scale).timeout
		if a.begins_with("panel="):
			for n in app.get_children():
				if n is BaseScreen:
					var what := a.substr(6)
					if what == "heroes": n._open(n._heroes_panel())
					elif what == "deck": n._open(n._deck_panel())
					elif what == "chests": n._open(n._chests_panel())
					elif what.begins_with("book:"): n._open(n._book_panel(what.substr(5)))
					elif what == "world": n._open(n._world_panel())
					elif what == "quests": n._open(n._quests_panel())
					elif what == "openchest": n._open_chest(0)
					elif what.begins_with("building:"): n._open(n._building_panel(what.substr(9)))
	await create_timer(1.2 * Engine.time_scale).timeout
	root.get_texture().get_image().save_png(out)
	quit()
