class_name BattleArena
extends Node3D
## The cinematic battle scene (6-8 seconds).
##
## When a unit attacks, the game cuts to this arena: both characters at full
## size, facing each other, on ground that matches the square they fight on
## (forest, hill, castle, bridge, crystal mine, open field). Health bars float
## over their heads. They trade blows until the loser falls - the result was
## already decided by the dice in Rules; this scene only shows it.
##
## The arena lives far below the board and is hidden when not in use.

signal finished

const ORIGIN := Vector3(0, -400, 0)
const ENV_DIR := "res://assets/environment/kaykit/"
const FIGHTER_SCALE := 1.5

var _camera: Camera3D
var _set: Node3D           # terrain decoration, rebuilt per battle
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
	_bars.layer = 8
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


## Plays one attack. `e` is the "attack" event from Rules (damage, counter and
## health before/after are already decided).
func play(e: Dictionary, terrain: int, att_color: int, hud: Hud) -> void:
	_skip = false
	_build_set(terrain, att_color)
	var a := _spawn(e["attacker_kind"], att_color, Vector3(-1.7, 0, 0), 90.0)
	var d := _spawn(e["defender_kind"], Chess.other(att_color), Vector3(1.7, 0, 0), -90.0)
	_lights[0].light_color = Style.team(att_color)["ui"]
	_lights[1].light_color = Style.team(Chess.other(att_color))["ui"]
	var a_max := UnitData.max_hp(e["attacker_kind"])
	var d_max := UnitData.max_hp(e["defender_kind"])
	await hud.fade(1.0, 0.25)
	visible = true
	_camera.make_current()
	_shot(Vector3(0, 3.4, 10.5), Vector3(0, 1.2, 0))
	_bar_a.setup(Texts.character(e["attacker_kind"], att_color), UnitData.attack(e["attacker_kind"]), Style.team(att_color)["ui"])
	_bar_d.setup(Texts.character(e["defender_kind"], Chess.other(att_color)), UnitData.attack(e["defender_kind"]), Style.team(Chess.other(att_color))["ui"])
	_bar_a.set_hp(100.0 * int(e["attacker_hp_before"]) / a_max)
	_bar_d.set_hp(100.0 * int(e["defender_hp_before"]) / d_max)
	_bar_a.target = a
	_bar_d.target = d
	_bar_a.cam = _camera
	_bar_d.cam = _camera
	_bars.visible = true
	hud.show_battle_skip(true)
	await hud.fade(0.0, 0.3)
	var tw := create_tween()
	tw.tween_method(func(t: float): _shot(Vector3(0, 3.4 - t * 0.6, 10.5 - t * 2.5), Vector3(0, 1.2, 0)), 0.0, 1.0, 0.9)
	await _wait(0.9)
	var d_dead := int(e["defender_hp"]) <= 0
	var a_dead := int(e["attacker_hp"]) <= 0
	# The attacker strikes...
	if not _skip:
		_shot(Vector3(-6.0, 3.0, 5.5), Vector3(0.8, 1.2, 0))
		await _strike(a, d, _bar_d, roundi(100.0 * int(e["damage"]) / d_max), d_dead, int(e["damage"]))
	# ...and the defender hits back if it can.
	if not _skip and int(e["counter"]) > 0:
		_shot(Vector3(6.0, 3.0, 5.5), Vector3(-0.8, 1.2, 0))
		await _strike(d, a, _bar_a, roundi(100.0 * int(e["counter"]) / a_max), a_dead, int(e["counter"]))
	_bar_d.set_hp(100.0 * int(e["defender_hp"]) / d_max)
	_bar_a.set_hp(100.0 * int(e["attacker_hp"]) / a_max)
	# Finale: whoever fell, falls; the other cheers.
	var loser: Node3D = d if d_dead else (a if a_dead else null)
	var winner: Node3D = a if d_dead else (d if a_dead else null)
	if loser != null:
		_shot(loser.position + Vector3(0, 2.2, 6.0), loser.position + Vector3(0, 1.0, 0))
		_play(loser, "death")
		await _wait(0.9)
	if winner != null:
		_play(winner, "victory")
	else:
		_shot(Vector3(0, 3.0, 8.5), Vector3(0, 1.2, 0))
		_play(a, "idle", true)
		_play(d, "idle", true)
	if not _skip:
		await _wait(1.0)
	await hud.fade(1.0, 0.25)
	hud.show_battle_skip(false)
	_bars.visible = false
	visible = false
	for c in _fighters.get_children():
		c.queue_free()
	finished.emit()


# ------------------------------------------------------------ the fight

## One blow: `damage` is in bar percent, `shown` is the real number that pops up.
func _strike(striker: Node3D, target: Node3D, bar: BattleHealthBar, damage: int, final: bool, shown: int) -> void:
	var home := striker.position
	var toward := (target.position - striker.position).normalized()
	var tw := create_tween()
	tw.tween_property(striker, "position", home + toward * 0.9, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_play(striker, "attack")
	await _wait(0.35)
	# Impact
	_play(target, "hit")
	Effects.burst(self, target.position + Vector3(0, 1.3, 0) - toward * 0.3, Color(1.0, 0.85, 0.35), 30, 3.5, 0.06)
	_flash_target(target)
	bar.damage(damage)
	_floating_number(target.position + Vector3(0, 2.8, 0), shown)
	if final:
		Engine.time_scale = 0.35
		await _wait(0.25)
		Engine.time_scale = 1.0
	var back := create_tween()
	back.tween_property(striker, "position", home, 0.3)
	await _wait(0.55)


func _flash_target(target: Node3D) -> void:
	var tw := create_tween()
	tw.tween_property(target, "scale", target.scale * Vector3(1.12, 0.9, 1.12), 0.06)
	tw.tween_property(target, "scale", target.scale, 0.12)


func _floating_number(pos: Vector3, amount: int) -> void:
	var l := Label3D.new()
	l.text = str(amount)
	l.font = UiKit.title_font()
	l.font_size = 96
	l.pixel_size = 0.008
	l.modulate = Color(1.0, 0.35, 0.25)
	l.outline_size = 18
	l.outline_modulate = Color(0.1, 0.02, 0.02)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position", pos + Vector3(0, 1.0, 0), 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


func _wait(seconds: float) -> void:
	if _skip:
		await get_tree().process_frame
		return
	await get_tree().create_timer(seconds, true, false, true).timeout


func _shot(pos: Vector3, look: Vector3) -> void:
	_camera.position = pos
	_camera.look_at(global_position + look, Vector3.UP)


# ------------------------------------------------------------ characters

func _spawn(kind: int, color: int, pos: Vector3, yaw: float) -> Node3D:
	var model := PieceModelFactory.build(kind, color)
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation_degrees.y = yaw
	holder.scale = Vector3.ONE * FIGHTER_SCALE
	holder.set_meta("anims", model.get_meta("anims", {}))
	holder.set_meta("player", model.get_meta("player", null))
	holder.add_child(model)
	_fighters.add_child(holder)
	_play(holder, "idle", true)
	return holder


func _play(fighter: Node3D, role: String, loop: bool = false) -> void:
	var player: AnimationPlayer = fighter.get_meta("player", null)
	var anims: Dictionary = fighter.get_meta("anims", {})
	if player == null or not anims.has(role) or not player.has_animation(anims[role]):
		return
	player.get_animation(anims[role]).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	player.play(anims[role], 0.12)


# ------------------------------------------------------------ the set

## Builds the ground and surroundings for the terrain the battle happens on.
func _build_set(terrain: int, att_color: int) -> void:
	for c in _set.get_children():
		c.queue_free()
	var ground_color := Style.TILE_DARK
	match terrain:
		Chess.Terrain.FOREST: ground_color = Style.TILE_FOREST
		Chess.Terrain.HILL: ground_color = Style.TILE_HILL
		Chess.Terrain.MINE: ground_color = Style.TILE_MINE
		Chess.Terrain.CASTLE: ground_color = Style.TILE_CASTLE
		Chess.Terrain.BRIDGE: ground_color = Color(0.40, 0.26, 0.14)
		_: ground_color = Style.GRASS.lightened(0.1)
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 7.0
	cyl.bottom_radius = 7.5
	cyl.height = 0.5
	disc.mesh = cyl
	disc.material_override = Style.matte(ground_color)
	disc.position = Vector3(0, -0.25, 0)
	_set.add_child(disc)
	var floor_plane := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	floor_plane.mesh = plane
	floor_plane.material_override = Style.matte(Style.GRASS.darkened(0.3))
	floor_plane.position = Vector3(0, -0.45, 0)
	_set.add_child(floor_plane)
	var rng := RandomNumberGenerator.new()
	rng.seed = terrain * 31 + 7
	match terrain:
		Chess.Terrain.FOREST:
			# Trees only behind and beside the fighters, never between them and the camera.
			for i in 14:
				var x := lerpf(-11.0, 11.0, i / 13.0) + rng.randf_range(-0.5, 0.5)
				var z := rng.randf_range(-9.0, -4.0) if absf(x) < 7.0 else rng.randf_range(-6.0, 1.0)
				_prop(["trees_A_large", "trees_B_large", "trees_A_medium"][i % 3], Vector3(x, 0, z), rng.randf_range(1.6, 2.4))
		Chess.Terrain.HILL:
			_prop("mountain_A_grass_trees", Vector3(-5, -0.4, -6), 2.6)
			_prop("hills_A_trees", Vector3(5, -0.4, -6), 2.4)
			for i in 6:
				_prop(["rock_single_A", "rock_single_B", "rock_single_C"][i % 3], Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-5, -2)), rng.randf_range(1.5, 2.5))
		Chess.Terrain.CASTLE:
			var team := "blue" if att_color == Chess.BLACK else "red"
			_prop("building_castle_" + team, Vector3(0, -0.3, -7), 3.2)
			_prop("flag_blue", Vector3(-4, 0, -3), 2.0)
			_prop("flag_red", Vector3(4, 0, -3), 2.0)
		Chess.Terrain.BRIDGE:
			var water := MeshInstance3D.new()
			var wp := PlaneMesh.new()
			wp.size = Vector2(80, 80)
			water.mesh = wp
			var wm := ShaderMaterial.new()
			wm.shader = preload("res://presentation/shaders/water.gdshader")
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
				mi.position = Vector3(cos(a) * rng.randf_range(4.5, 6.5), c.height * 0.4, -abs(sin(a)) * rng.randf_range(3.0, 6.0))
				mi.rotation_degrees = Vector3(rng.randf_range(-20, 20), 0, rng.randf_range(-20, 20))
				_set.add_child(mi)
		_:
			_prop("tent", Vector3(-5.5, 0, -4.5), 2.0)
			_prop("weaponrack", Vector3(4.5, 0, -4), 2.0)
			_prop("flag_blue", Vector3(-3, 0, -5), 2.0)
			_prop("flag_red", Vector3(3, 0, -5), 2.0)
			for i in 5:
				_prop("rock_single_" + ["A", "B", "C"][i % 3], Vector3(rng.randf_range(-7, 7), 0, rng.randf_range(-6, -3)), 1.6)


func _prop(model: String, pos: Vector3, s: float) -> void:
	var path := ENV_DIR + model + ".gltf"
	if not ResourceLoader.exists(path):
		return
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.position = pos
	inst.scale = Vector3.ONE * s
	_set.add_child(inst)
