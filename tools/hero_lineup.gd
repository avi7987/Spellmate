extends SceneTree
## Takes a picture of every hero of both kingdoms standing in rows.
## xvfb-run -a godot --rendering-driver opengl3 --script res://tools/hero_lineup.gd -- out.png [team] [ids,comma,separated]

func _init() -> void:
	await process_frame
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://lineup.png"
	var teams := [0, 1] if args.size() < 2 or args[1] == "both" else [int(args[1])]
	var ids: Array = BattleData.hero_ids() if args.size() < 3 else Array(args[2].split(","))
	DisplayServer.window_set_size(Vector2i(1800, 560 * teams.size()))
	var world := Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.12, 0.15)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.55, 0.5)
	env.environment.ambient_light_energy = 0.6
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 30, 0)
	sun.light_energy = 1.0
	world.add_child(sun)
	var floor_ := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 20)
	floor_.mesh = pm
	floor_.material_override = Style.matte(Color(0.3, 0.36, 0.22))
	world.add_child(floor_)
	var n := ids.size()
	for row in teams.size():
		for i in n:
			var m := PieceModelFactory.build_hero(ids[i], teams[row])
			world.add_child(m)
			m.position = Vector3((i - (n - 1) / 2.0) * 1.35, 0, row * 2.2)
			var player: AnimationPlayer = (m.get_meta("player") if m.has_meta("player") else null)
			var anims: Dictionary = m.get_meta("anims")
			if player and anims.has("idle") and player.has_animation(anims["idle"]):
				player.play(anims["idle"])
				player.seek(0.4, true)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = n * 1.35 * 0.62 + 1.0
	world.add_child(cam)
	var cz := (teams.size() - 1) * 1.1
	cam.position = Vector3(0, 6, cz + 12)
	if args.size() > 3 and args[3] == "top":
		cam.position = Vector3(0, 14, cz + 10)
		cam.size *= 1.25
	cam.look_at(Vector3(0, 0.7, cz))
	for i in 12:
		await process_frame
	root.get_texture().get_image().save_png(out)
	quit()
