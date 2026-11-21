extends Node3D
## Entry point of the game. Builds the shared world (light, sky, camera),
## loads the player's profile and switches between the screens:
##   base village (BaseScreen)  <->  battle (BattleScreen)  ->  results
## The first time, a short guided battle (tutorial) starts right away.

var camera_rig: CameraRig
var portraits: Portraits
var profile: Profile
var _env: Environment
var _sun: DirectionalLight3D
var _screen: Node = null
var _overlay: CanvasLayer


func _ready() -> void:
	randomize()
	UiKit.setup_fonts()
	_build_world()
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	portraits = Portraits.new()
	add_child(portraits)
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	add_child(_overlay)
	profile = Profile.load_or_new()
	Sfx.volume = float(profile.settings.get("sfx", 0.8))
	Music.volume = float(profile.settings.get("music", 0.45))
	var args := OS.get_cmdline_user_args()
	if args.has("--battle"):
		var size: String = args[args.find("--battle") + 1] if args.size() > args.find("--battle") + 1 else "small"
		var world: String = args[args.find("--world") + 1] if args.has("--world") else ""
		if args.has("--mode"):
			profile.settings["mode"] = args[args.find("--mode") + 1]
		start_battle(size, args.has("--autoplay"), world)
	elif not profile.tutorial_done and not args.has("--base"):
		start_tutorial()
	else:
		go_base()


func _build_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.3, 0.45)
	sky_mat.sky_horizon_color = Color(0.6, 0.55, 0.5)
	sky_mat.ground_bottom_color = Color(0.15, 0.13, 0.1)
	sky_mat.ground_horizon_color = Color(0.45, 0.4, 0.35)
	sky_mat.energy_multiplier = 0.3
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_hdr_threshold = 1.1
	var m: Dictionary = Style.MOOD[0]
	_env.ambient_light_color = m["ambient"]
	_env.ambient_light_energy = m["ambient_energy"] + 0.08
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-58, 30, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 45.0
	_sun.light_color = m["sun"]
	_sun.light_energy = m["sun_energy"]
	add_child(_sun)


## The light and sky of a world (or the normal look when biome is empty).
func apply_world(biome: Dictionary) -> void:
	var c: Dictionary = biome.get("colors", {})
	var m: Dictionary = Style.MOOD[0]
	_sun.light_color = Color.html(c["sun"]) if c.has("sun") else m["sun"]
	_env.ambient_light_color = Color.html(c["ambient"]) if c.has("ambient") else m["ambient"]
	var sky := _env.sky.sky_material as ProceduralSkyMaterial
	sky.sky_top_color = Color.html(c["sky"]).darkened(0.3) if c.has("sky") else Color(0.25, 0.3, 0.45)
	sky.sky_horizon_color = Color.html(c["sky"]) if c.has("sky") else Color(0.6, 0.55, 0.5)
	_env.fog_enabled = biome.get("props", "") in ["dead_trees", "mushrooms", "graves"]
	_env.fog_light_color = Color.html(c.get("sky", "#808080"))
	_env.fog_density = 0.008


## Day / night / eclipse light during a battle.
func set_sky(sky_name: String, biome: Dictionary) -> void:
	var c: Dictionary = biome.get("colors", {})
	var day_sun: Color = Color.html(c["sun"]) if c.has("sun") else Style.MOOD[0]["sun"]
	var day_amb: Color = Color.html(c["ambient"]) if c.has("ambient") else Style.MOOD[0]["ambient"]
	var targets := { "sun": day_sun, "energy": 1.0, "amb": day_amb, "amb_e": 0.5 }
	match sky_name:
		"night":
			targets = { "sun": Color(0.55, 0.6, 1.0), "energy": 0.45, "amb": Color(0.35, 0.3, 0.6), "amb_e": 0.55 }
		"eclipse":
			targets = { "sun": Color(1.0, 0.45, 0.3), "energy": 0.3, "amb": Color(0.45, 0.2, 0.3), "amb_e": 0.5 }
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sun, "light_color", targets["sun"], 1.5)
	tw.tween_property(_sun, "light_energy", targets["energy"], 1.5)
	tw.tween_property(_env, "ambient_light_color", targets["amb"], 1.5)
	tw.tween_property(_env, "ambient_light_energy", targets["amb_e"], 1.5)


func _swap(screen: Node) -> void:
	if _screen != null:
		_screen.queue_free()
	for c in _overlay.get_children():
		c.queue_free()
	_screen = screen
	add_child(screen)


func go_base() -> void:
	apply_world({})
	var base := BaseScreen.new()
	base.app = self
	_swap(base)
	base.open()


## A battle with the current deck against the computer of the current arena.
func start_battle(size: String, autoplay: bool = false, biome: String = "") -> void:
	if biome == "":
		biome = profile.settings.get("world", "meadow")
	apply_world(BattleData.biome(biome))
	await portraits.render(profile.deck + BattleData.hero_ids(), 0)
	var arena := profile.arena()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var ai_levels := {}
	for id in BattleData.hero_ids():
		ai_levels[id] = int(arena["ai_level"])
	var bs := BattleScreen.new()
	bs.camera_rig = camera_rig
	bs.app = self
	_swap(bs)
	bs.scene_mode = profile.settings.get("scenes", "always")
	bs.rival = arena
	bs.start(size, profile.deck, profile.levels(), profile.enemy_deck(rng), int(arena["ai"]), ai_levels, biome, profile.settings.get("mode", "mate"))
	bs.battle.apply_bonuses(0, profile.palace_bonus(), profile.start_energy_bonus())
	bs.battle.loadout[0] = profile.settings.get("powers", {}).duplicate()
	if autoplay:
		bs.autoplay = BattleAI.new(0, 2)
	bs.finished.connect(_on_battle_finished)


func start_tutorial() -> void:
	await portraits.render(profile.deck + ["king", "queen"], 0)
	var bs := BattleScreen.new()
	bs.camera_rig = camera_rig
	_swap(bs)
	bs.start("small", profile.deck, profile.levels(), ["miner", "soldier", "archer", "soldier", "archer", "soldier", "ice_bomb", "fire_bomb"], 0)
	var guide := TutorialGuide.new()
	bs.add_child(guide)
	bs.tutorial = guide
	guide.setup(bs)
	bs.finished.connect(func(result):
		profile.tutorial_done = true
		_on_battle_finished(result))


func _on_battle_finished(result: Dictionary) -> void:
	var rewards := profile.apply_battle(result)
	profile.save()
	var panel := ResultsPanel.new()
	_overlay.add_child(panel)
	panel.show_results(result, rewards, profile)
	await panel.closed
	go_base()


func save_settings() -> void:
	profile.settings["sfx"] = Sfx.volume
	profile.settings["music"] = Music.volume
	profile.save()
