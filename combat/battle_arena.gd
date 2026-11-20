class_name BattleArena
extends Node3D
## The cinematic battle scene (about 5 seconds), like in the first version.
##
## When a hero defeats another hero, the game cuts to this arena: both
## characters at full size facing each other, health bars over their heads,
## and they trade blows until the loser falls. The place matches where the
## fight happened: the world (meadow, swamp, fire, ice, desert, candy,
## mushrooms) and the square (forest, hill, palace, bridge, mine, special
## ground). The result already happened in the battle - this only shows it.
##
## The arena lives far below the map and is hidden when not in use.

signal finished

const ORIGIN := Vector3(0, -400, 0)
const ENV_DIR := "res://assets/environment/kaykit/"
const FIGHTER_SCALE := 1.5

var _camera: Camera3D
var _set: Node3D
var _fighters: Node3D
var _bars: CanvasLayer
var _bar_a: BattleHealthBar
var _bar_d: BattleHealthBar
var _skip := false
var _lights: Array = []


func _ready() -> void:
	position = ORIGIN
	visible = false
	_camera = Camera3D.new()
	_camera.fov = 42.0
	add_child(_camera)
	_set = Node3D.new()
	add_child(_set)
	_fighters = Node3D.new()
	add_child(_fighters)
	_bars = CanvasLayer.new()
	_bars.layer = 12
	_bars.visible = false
	add_child(_bars)
	_bar_a = BattleHealthBar.new()
	_bar_d = BattleHealthBar.new()
	_bars.add_child(_bar_a)
	_bars.add_child(_bar_d)
	for p in [Vector3(-3, 4, 3), Vector3(3, 3, -2)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 12.0
		l.light_energy = 0.9
		add_child(l)
		_lights.append(l)


func skip() -> void:
	_skip = true


## Shows how `e` (a "death" event with killer info) happened.
func play(e: Dictionary, world: Dictionary, killer_team: int, hud: BattleHud) -> void:
	_skip = false
	var victim_team: int = e["team"]
	_build_set(int(e.get("terrain", Chess.Terrain.PLAIN)), world)
	var a := _spawn(e["killer"], killer_team, Vector3(-1.8, 0, 0), 90.0)
	var d := _spawn(e["kind"], victim_team, Vector3(1.8, 0, 0), -90.0)
	_lights[0].light_color = Style.team(killer_team)["ui"]
	_lights[1].light_color = Style.team(victim_team)["ui"]
	await hud.fade(1.0, 0.25)
	visible = true
	_camera.make_current()
	_shot(Vector3(0, 3.4, 10.5), Vector3(0, 1.2, 0))
	_bar_a.setup(_name(e["killer"]), _power(e["killer"]), Style.team(killer_team)["ui"])
	_bar_d.setup(_name(e["kind"]), _power(e["kind"]), Style.team(victim_team)["ui"])
	var a_end := clampf(float(e.get("killer_hp", 1.0)) * 100.0, 8.0, 100.0)
	var a_start := minf(100.0, a_end + randf_range(10.0, 25.0))
	var d_start := randf_range(45.0, 80.0)
	_bar_a.set_hp(a_start)
	_bar_d.set_hp(d_start)
	_bar_a.target = a
	_bar_d.target = d
	_bar_a.cam = _camera
	_bar_d.cam = _camera
	_bars.visible = true
	hud.cinematic(true, "")
	await hud.fade(0.0, 0.3)
	var tw := create_tween()
	tw.tween_method(func(t: float): _shot(Vector3(0, 3.4 - t * 0.6, 10.5 - t * 2.5), Vector3(0, 1.2, 0)), 0.0, 1.0, 0.8)
	await _wait(0.8)
	# blow, counter-blow, final blow
	if not _skip:
		_shot(Vector3(-6.0, 3.0, 5.5), Vector3(0.8, 1.2, 0))
		await _strike(a, d, _bar_d, d_start * 0.45, false)
	if not _skip:
		_shot(Vector3(6.0, 3.0, 5.5), Vector3(-0.8, 1.2, 0))
		await _strike(d, a, _bar_a, a_start - a_end, false)
	if not _skip:
		_shot(Vector3(-5.0, 2.6, 6.5), Vector3(0.8, 1.2, 0))
		await _strike(a, d, _bar_d, 100.0, true)
	_bar_d.set_hp(0.0)
	_bar_a.set_hp(a_end)
	_shot(d.position + Vector3(0, 2.2, 6.0), d.position + Vector3(0, 1.0, 0))
	_play(d, "death")
	_play(a, "victory")
	if not _skip:
		await _wait(1.1)
	await hud.fade(1.0, 0.25)
	_bars.visible = false
	visible = false
	for c in _fighters.get_children():
		c.queue_free()
	hud.cinematic(false, "")
	finished.emit()


func _name(kind: String) -> String:
	var m: Dictionary = BattleData.biomes().get("monsters", {})
	return m[kind]["name"] if m.has(kind) else HeroTexts.name_of(kind)


func _power(kind: String) -> int:
	var m: Dictionary = BattleData.biomes().get("monsters", {})
	return int(m[kind]["dmg"]) if m.has(kind) else int(BattleData.hero(kind).get("dmg", 0))


# ------------------------------------------------------------ the fight

func _strike(striker: Node3D, target: Node3D, bar: BattleHealthBar, damage: float, final: bool) -> void:
	var home := striker.position
	var toward := (target.position - striker.position).normalized()
	var tw := create_tween()
	tw.tween_property(striker, "position", home + toward * 0.9, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_play(striker, "attack")
	Sfx.play("hit")
	await _wait(0.35)
	_play(target, "hit")
	Effects.burst(self, target.position + Vector3(0, 1.3, 0) - toward * 0.3, Color(1.0, 0.85, 0.35), 30, 3.5, 0.06)
	var flash := create_tween()
	flash.tween_property(target, "scale", target.scale * Vector3(1.12, 0.9, 1.12), 0.06)
	flash.tween_property(target, "scale", target.scale, 0.12)
	bar.damage(damage)
	if final:
		Sfx.play("boom", 0.7)
		Engine.time_scale = 0.35
		await _wait(0.25)
		Engine.time_scale = 1.0
	var back := create_tween()
	back.tween_property(striker, "position", home, 0.3)
	await _wait(0.5)


func _wait(seconds: float) -> void:
	if _skip:
		Engine.time_scale = 1.0
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(pos: Vector3, look: Vector3) -> void:
	_camera.position = pos
	_camera.look_at(global_position + look, Vector3.UP)


func _spawn(kind: String, team: int, pos: Vector3, yaw: float) -> Node3D:
	var model := PieceModelFactory.build_hero(kind, team)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = yaw
	holder.scale = Vector3.ONE * FIGHTER_SCALE * (0.6 if kind == "dragon" else 1.0)
	holder.set_meta("anims", model.get_meta("anims", {}))
	holder.set_meta("player", model.get_meta("player") if model.has_meta("player") else null)
	holder.add_child(model)
	_fighters.add_child(holder)
	_play(holder, "idle", true)
	return holder


func _play(fighter: Node3D, role: String, loop: bool = false) -> void:
	var player: AnimationPlayer = fighter.get_meta("player") if fighter.has_meta("player") else null
	var anims: Dictionary = fighter.get_meta("anims", {})
	if player == null or not anims.has(role) or not player.has_animation(anims[role]):
		# shape models: a little hop instead
		var tw := create_tween()
		tw.tween_property(fighter, "position:y", 0.4, 0.12)
		tw.tween_property(fighter, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_BOUNCE)
		return
	player.get_animation(anims[role]).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	player.play(anims[role], 0.12)


# ------------------------------------------------------------ the set

## The ground and surroundings: the world's colours and plants, plus what is
## special about the square (palace, bridge, mine, forest, hill, lava...).
func _build_set(terrain: int, world: Dictionary) -> void:
	for c in _set.get_children():
		c.queue_free()
	var col: Dictionary = world.get("colors", {})
	var ground := Color.html(col.get("plain", "#4c6638"))
	match terrain:
		Chess.Terrain.FOREST: ground = Color.html(col.get("forest", "#33512b"))
		Chess.Terrain.HILL: ground = Color.html(col.get("hill", "#706650"))
		Chess.Terrain.SPECIAL: ground = Color.html(col.get("special", "#5f7a3c"))
		Chess.Terrain.MINE: ground = Style.TILE_MINE
		Chess.Terrain.CASTLE, Chess.Terrain.WALL: ground = Style.TILE_CASTLE
		Chess.Terrain.BRIDGE: ground = Color(0.40, 0.26, 0.14)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 7.0
	cyl.bottom_radius = 7.5
	cyl.height = 0.5
	disc.mesh = cyl
	var lava: bool = world.get("special", {}).has("dps") and terrain == Chess.Terrain.SPECIAL
	disc.material_override = Style.glow(ground, 1.2) if lava else Style.matte(ground)
	disc.position = Vector3(0, -0.25, 0)
	_set.add_child(disc)
	var floor_plane := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(90, 90)
	floor_plane.mesh = plane
	floor_plane.material_override = Style.matte(Color.html(col.get("rim", "#2b3d22")))
	floor_plane.position = Vector3(0, -0.45, 0)
	_set.add_child(floor_plane)
	# the world's plants behind and beside the fighters (never between them and the camera)
	var plants := TerrainView.new()
	plants.scale = Vector3.ONE * 3.0
	_set.add_child(plants)
	plants._biome = world
	plants._props = world.get("props", "trees")
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain * 31 + 7
	var count := 16 if terrain == Chess.Terrain.FOREST else 8
	for i in count:
		var x := lerpf(-11.0, 11.0, i / float(count - 1)) + rng.randf_range(-0.5, 0.5)
		var z := rng.randf_range(-9.0, -4.0) if absf(x) < 7.0 else rng.randf_range(-6.0, 1.0)
		if plants._props == "trees":
			_prop(["trees_A_large", "trees_B_large", "trees_A_medium"][i % 3], Vector3(x, 0, z), rng.randf_range(1.6, 2.4))
		else:
			plants._world_prop(Vector3(x, 0, z) / 3.0, rng)
	match terrain:
		Chess.Terrain.HILL:
			_prop("mountain_A_grass_trees", Vector3(-5, -0.4, -6), 2.6)
			_prop("hills_A_trees", Vector3(5, -0.4, -6), 2.4)
		Chess.Terrain.CASTLE, Chess.Terrain.WALL:
			_prop("building_castle_blue", Vector3(0, -0.3, -7), 3.2)
			_prop("flag_blue", Vector3(-4, 0, -3), 2.0)
			_prop("flag_red", Vector3(4, 0, -3), 2.0)
		Chess.Terrain.BRIDGE, Chess.Terrain.WATER:
			var water := MeshInstance3D.new()
			var wp := PlaneMesh.new()
			wp.size = Vector2(90, 90)
			water.mesh = wp
			var wm := ShaderMaterial.new()
			wm.shader = preload("res://presentation/shaders/water.gdshader")
			var wc := Color.html(col.get("water", "#3a7fb5"))
			wm.set_shader_parameter("deep", wc.darkened(0.45))
			wm.set_shader_parameter("shallow", wc)
			water.material_override = wm
			water.position = Vector3(0, -0.35, 0)
			_set.add_child(water)
			floor_plane.visible = false
			disc.scale = Vector3(1, 1, 0.45)
		Chess.Terrain.MINE:
			var glow := Style.glow(Style.CRYSTAL, 2.5)
			for i in 10:
				var mi := MeshInstance3D.new()
				var c := CylinderMesh.new()
				c.top_radius = 0.0
				c.bottom_radius = rng.randf_range(0.2, 0.45)
				c.height = rng.randf_range(1.0, 2.6)
				c.radial_segments = 5
				mi.mesh = c
				mi.material_override = glow
				var a := PI + TAU * i / 20.0 + rng.randf() * 0.3
				mi.position = Vector3(cos(a) * rng.randf_range(4.5, 6.5), c.height * 0.4, -absf(sin(a)) * rng.randf_range(3.0, 6.0))
				_set.add_child(mi)
		_:
			_prop("flag_blue", Vector3(-3, 0, -5), 2.0)
			_prop("flag_red", Vector3(3, 0, -5), 2.0)


func _prop(model: String, pos: Vector3, s: float) -> void:
	var path := ENV_DIR + model + ".gltf"
	if not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = pos
	inst.scale = Vector3.ONE * s
	_set.add_child(inst)
