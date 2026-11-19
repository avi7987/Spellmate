class_name BoardView
extends Node3D
## Draws the world: terrain, units, palace gates and towers, the fog of war,
## highlights and effects, and plays the animations for every action.
## It only READS the GameState; changes always go through GameController.

## square = the unit clicked (or the ground square); ground = the square under the cursor.
signal square_clicked(square: int, ground: int)
signal presentation_done
signal square_hovered(square: int)

enum Mark { MOVE, CAPTURE, POWER, SELECTED, HOVER, LAST, CHECK }

const TILE_HEIGHT := 0.2
const HALF_W := (Chess.W - 1) / 2.0
const HALF_H := (Chess.H - 1) / 2.0
const HIGHLIGHT_SHADER := preload("res://presentation/shaders/highlight.gdshader")
const PERCENT_FONT := preload("res://assets/fonts/SuezOne.ttf")
const ENV_DIR := "res://assets/environment/kaykit/"

var combat: CombatDirector
var camera_rig: CameraRig
## Whose eyes the fog of war uses (-1 = see everything).
var viewer: int = Chess.WHITE

var _pieces: Dictionary = {}       # piece id -> PieceView
var _structures: Dictionary = {}   # structure id -> Node3D
var _highlight_root: Node3D
var _fx_root: Node3D
var _lava_root: Node3D
var _pieces_root: Node3D
var _structures_root: Node3D
var _terrain_view: TerrainView
var _terrain: PackedInt32Array
var _accent_mat: StandardMaterial3D
var _fog: MultiMeshInstance3D
var _visible := PackedByteArray()
var _hover_root: Node3D
var _hover_square := -1
var hover_enabled := true


## Centre of a square at board height 0.
static func square_xz(s: int) -> Vector3:
	return Vector3(Chess.file_of(s) - HALF_W, 0, HALF_H - Chess.rank_of(s))


## Where a unit stands on a square (on top of the tile; hills are higher).
func square_to_world(s: int) -> Vector3:
	var t: int = _terrain[s] if _terrain.size() == Chess.N else Chess.Terrain.PLAIN
	return square_xz(s) + Vector3(0, TerrainView.top_of(t), 0)


static func world_to_square(p: Vector3) -> int:
	var f := floori(p.x + Chess.W / 2.0)
	var r := floori(Chess.H / 2.0 - p.z)
	return Chess.sq(f, r) if Chess.on_board(f, r) else -1


func _ready() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200, 200)
	ground.mesh = plane
	ground.material_override = Style.matte(Style.GRASS.darkened(0.2))
	ground.position = Vector3(0, -0.4, 0)
	add_child(ground)
	var fw := Chess.W + 1.3
	var fh := Chess.H + 1.3
	_add_box(Vector3(fw, 0.3, fh), Vector3(0, -0.36, 0), Style.matte(Style.FRAME_WOOD))
	_add_box(Vector3(Chess.W + 0.5, 0.1, Chess.H + 0.5), Vector3(0, -0.2, 0), Style.metal(Style.FRAME_GOLD))
	_accent_mat = StandardMaterial3D.new()
	_accent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_accent_mat.albedo_color = Style.MOOD[Chess.WHITE]["accent"]
	var ex := Chess.W / 2.0 + 0.06
	var ez := Chess.H / 2.0 + 0.06
	for side in [[Vector3(Chess.W + 0.2, 0.04, 0.08), Vector3(0, 0.02, ez)], [Vector3(Chess.W + 0.2, 0.04, 0.08), Vector3(0, 0.02, -ez)],
			[Vector3(0.08, 0.04, Chess.H + 0.2), Vector3(ex, 0.02, 0)], [Vector3(0.08, 0.04, Chess.H + 0.2), Vector3(-ex, 0.02, 0)]]:
		_add_box(side[0], side[1], _accent_mat)
	_terrain_view = TerrainView.new()
	add_child(_terrain_view)
	_structures_root = Node3D.new()
	add_child(_structures_root)
	_pieces_root = Node3D.new()
	add_child(_pieces_root)
	_lava_root = Node3D.new()
	add_child(_lava_root)
	_highlight_root = Node3D.new()
	add_child(_highlight_root)
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_build_fog()


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


## Builds the terrain (rebuilt when it changes, e.g. a tower falls and leaves a breach).
func build_terrain(state: GameState) -> void:
	if _terrain == state.terrain:
		return
	_terrain = state.terrain.duplicate()
	_terrain_view.build(_terrain)


# ------------------------------------------------------------ fog of war

func _build_fog() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := BoxMesh.new()
	q.size = Vector3(1.0, 1.4, 1.0)
	mm.mesh = q
	mm.instance_count = Chess.N
	for s in Chess.N:
		mm.set_instance_transform(s, Transform3D(Basis.IDENTITY, square_xz(s) + Vector3(0, 0.55, 0)))
		mm.set_instance_color(s, Color(0, 0, 0, 0))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	_fog = MultiMeshInstance3D.new()
	_fog.multimesh = mm
	_fog.material_override = mat
	_fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fog)


func _update_fog(state: GameState) -> void:
	if viewer < 0:
		_visible = PackedByteArray()
		_visible.resize(Chess.N)
		_visible.fill(1)
	else:
		_visible = state.visible_squares(viewer)
	var mm := _fog.multimesh
	var explored: PackedByteArray = state.explored[viewer] if viewer >= 0 else _visible
	for s in Chess.N:
		var a := 0.0
		if _visible[s] == 0:
			a = 0.55 if explored[s] == 1 else 0.93
		mm.set_instance_color(s, Color(0.03, 0.03, 0.06, a))


func is_visible_square(s: int) -> bool:
	return _visible.size() == Chess.N and _visible[s] == 1


# ------------------------------------------------------------ units & structures

func sync(state: GameState) -> void:
	build_terrain(state)
	_update_fog(state)
	var seen := {}
	for s in Chess.N:
		var p := state.piece_at(s)
		if p == null:
			continue
		seen[p.id] = true
		var v: PieceView = _pieces.get(p.id)
		if v == null:
			v = PieceView.new()
			_pieces_root.add_child(v)
			v.setup(p)
			_pieces[p.id] = v
		v.visible = p.color == viewer or viewer < 0 or is_visible_square(s)
		v.scale = Vector3.ONE
		v.square = s
		v.position = square_to_world(s)
		v.set_kind(p.kind)
		v.set_status(state.is_shielded(p) or state.is_braced(p), state.is_frozen(p))
		v.set_health(p.hp, p.max_hp)
		v.set_spent(p.color == state.side_to_move and p.acted)
	for id in _pieces.keys():
		if not seen.has(id):
			_pieces[id].queue_free()
			_pieces.erase(id)
	_sync_structures(state)
	_sync_lava(state)


func _sync_structures(state: GameState) -> void:
	var seen := {}
	var explored: PackedByteArray = state.explored[viewer] if viewer >= 0 else _visible
	for st in state.structures:
		var id: int = st["id"]
		seen[id] = true
		var node: Node3D = _structures.get(id)
		if node == null:
			node = _build_structure(st)
			_structures_root.add_child(node)
			_structures[id] = node
		var bar: HealthBar3D = node.get_meta("bar")
		bar.set_health(int(st["hp"]), int(st["max_hp"]))
		node.visible = int(st["color"]) == viewer or viewer < 0 or explored[int(st["square"])] == 1
	for id in _structures.keys():
		if not seen.has(id):
			var gone: Node3D = _structures[id]
			Effects.burst(_fx_root, gone.position + Vector3(0, 0.8, 0), Color(0.7, 0.65, 0.6), 50, 4.0, 0.1)
			gone.queue_free()
			_structures.erase(id)


## A gate (stone posts, wooden door, team banner) or a tower (KayKit model).
func _build_structure(st: Dictionary) -> Node3D:
	var root := Node3D.new()
	var s: int = st["square"]
	var color: int = st["color"]
	root.position = square_xz(s) + Vector3(0, TILE_HEIGHT * 0.5, 0)
	var stone := Style.matte(Color(0.42, 0.41, 0.42))
	var team: Color = Style.team(color)["ui"]
	if st["kind"] == "gate":
		for x in [-0.42, 0.42]:
			var post := MeshInstance3D.new()
			var b := BoxMesh.new()
			b.size = Vector3(0.22, 1.3, 0.9)
			post.mesh = b
			post.material_override = stone
			post.position = Vector3(x, 0.65, 0)
			root.add_child(post)
		var door := MeshInstance3D.new()
		var d := BoxMesh.new()
		d.size = Vector3(0.66, 0.95, 0.18)
		door.mesh = d
		door.material_override = Style.toon(Color(0.36, 0.22, 0.12), 0.0, 0.9)
		door.position = Vector3(0, 0.48, 0)
		root.add_child(door)
		var banner := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(0.4, 0.45, 0.04)
		banner.mesh = bb
		banner.material_override = Style.cloth(team.darkened(0.3))
		banner.position = Vector3(0, 1.05, 0.12)
		root.add_child(banner)
	else:
		var path := ENV_DIR + ("building_tower_A_blue" if color == Chess.WHITE else "building_tower_A_red") + ".gltf"
		if ResourceLoader.exists(path):
			var tower := (load(path) as PackedScene).instantiate() as Node3D
			tower.scale = Vector3.ONE * 0.62
			tower.position = Vector3(0, 0.85, 0)
			root.add_child(tower)
	var bar := HealthBar3D.new()
	bar.position = Vector3(0, 2.1, 0)
	bar.bar_color = team
	root.add_child(bar)
	root.set_meta("bar", bar)
	return root


func structure_node(id: int) -> Node3D:
	return _structures.get(id)


func set_turn_accent(color: Color) -> void:
	create_tween().tween_property(_accent_mat, "albedo_color", color, 0.8)


## Victory: the winning side cheers (the king already fell in battle).
func play_victory(state: GameState, winner: int) -> void:
	for v in _pieces.values():
		var p := state.piece_at(v.square)
		if p != null and p.color == winner:
			v.play_action("victory", 1.0)
	await get_tree().create_timer(1.4).timeout


func view_of(id: int) -> PieceView:
	return _pieces.get(id)


func _sync_lava(state: GameState) -> void:
	for c in _lava_root.get_children():
		c.queue_free()
	for s in state.hazards:
		if not state.is_lava(s):
			continue
		var mi := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.96, 0.96)
		mi.mesh = plane
		mi.material_override = Style.glow(Style.LAVA, 1.6)
		mi.position = square_to_world(s) + Vector3(0, 0.005, 0)
		_lava_root.add_child(mi)
		var embers := CPUParticles3D.new()
		embers.amount = 8
		embers.lifetime = 1.2
		embers.direction = Vector3.UP
		embers.spread = 25
		embers.initial_velocity_min = 0.3
		embers.initial_velocity_max = 0.8
		embers.gravity = Vector3.ZERO
		embers.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
		embers.emission_box_extents = Vector3(0.4, 0.0, 0.4)
		var em := SphereMesh.new()
		em.radius = 0.04
		em.height = 0.08
		embers.mesh = em
		embers.material_override = Style.glow(Color(1.0, 0.75, 0.2), 3.0)
		embers.position = mi.position
		_lava_root.add_child(embers)


# ------------------------------------------------------------ highlights

func clear_highlights() -> void:
	for c in _highlight_root.get_children():
		c.queue_free()


## Draws an animated marker on a square (see highlight.gdshader for the looks).
func mark(s: int, kind: int, color: Color, parent: Node3D = null) -> void:
	if s < 0:
		return
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	mi.mesh = plane
	var mat := ShaderMaterial.new()
	mat.shader = HIGHLIGHT_SHADER
	mat.set_shader_parameter("color", color)
	mat.set_shader_parameter("mode", kind)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var y := TerrainView.top_of(_terrain[s]) if _terrain.size() == Chess.N else TILE_HEIGHT * 0.5
	mi.position = square_xz(s) + Vector3(0, y + 0.002 + 0.001 * kind, 0)
	(parent if parent != null else _highlight_root).add_child(mi)


## A short label floating over a square, e.g. the damage an attack would do.
func mark_text(s: int, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = PERCENT_FONT
	l.font_size = 56
	l.pixel_size = 0.0055
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.02, 0.02)
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.position = square_xz(s) + Vector3(0, 1.6, 0)
	_highlight_root.add_child(l)


func _update_hover(s: int) -> void:
	if s == _hover_square:
		return
	_hover_square = s
	if _hover_root == null:
		_hover_root = Node3D.new()
		add_child(_hover_root)
	for c in _hover_root.get_children():
		c.queue_free()
	if hover_enabled and s >= 0:
		mark(s, Mark.HOVER, Style.HL_HOVER, _hover_root)
	square_hovered.emit(s)


# ------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	var pressed: bool = (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and event.pressed)
	if pressed:
		var s := square_at_screen(event.position)
		if s >= 0:
			square_clicked.emit(s, camera_rig.square_at_screen(event.position))
	elif event is InputEventMouseMotion:
		_update_hover(square_at_screen(event.position))


## A click on a unit's body selects its square; otherwise the square under the cursor.
func square_at_screen(pos: Vector2) -> int:
	var cam := camera_rig.camera
	var best := -1
	var best_y := -INF
	for v in _pieces.values():
		if not v.visible or v.square < 0:
			continue
		var seg: Array = v.screen_segment(cam)
		var radius: float = (cam.unproject_position(v.global_position + Vector3(0.36, 0, 0)) - cam.unproject_position(v.global_position)).length()
		if Geometry2D.get_closest_point_to_segment(pos, seg[0], seg[1]).distance_to(pos) <= radius:
			if seg[0].y > best_y:
				best_y = seg[0].y
				best = v.square
	if best >= 0:
		return best
	return camera_rig.square_at_screen(pos)


# ------------------------------------------------------------ playing actions

## Animates what happened, then makes the view match the new state exactly.
func play_events(events: Array, state: GameState) -> void:
	for e in events:
		match e["type"]:
			"move":
				var v := view_of(e["piece_id"])
				# Units walking unseen in the fog are not animated.
				if v != null and (v.visible or is_visible_square(e["to"])):
					v.visible = true
					var pts := []
					for sq in e.get("path", [e["to"]]):
						pts.append(square_to_world(sq))
					await v.walk_path(pts)
			"attack":
				var a := view_of(e["attacker_id"])
				var d: Node3D = view_of(e["defender_id"]) if e.has("defender_id") else structure_node(e.get("structure_id", -1))
				await combat.play_battle(e, a, d, square_to_world(e["from"]), square_to_world(e["to"]), _terrain[e["to"]])
			"death":
				var dv := view_of(e["piece_id"])
				if dv != null and dv.visible and dv.scale.x > 0.5:
					if e["kind"] == Chess.Kind.KING:
						await dv.fall()
					else:
						await dv.defeat()
			"recruit":
				sync(state)
				var rv := view_of(e["piece_id"])
				if rv != null:
					Effects.pillar(_fx_root, square_to_world(e["square"]), Style.team(e["color"])["ui"], 3.0, 0.7)
					await rv.pop_in()
			"ability":
				var caster := view_of(e["piece_id"])
				var at := square_to_world(e["from"])
				var col := Style.power_color(e["ability_id"])
				if camera_rig != null:
					await camera_rig.focus(at, 7.0, 0.45)
				Effects.ring(_fx_root, at, col, 1.6, 0.5)
				Effects.pillar(_fx_root, at, col)
				if caster != null:
					await caster.play_action("cast", 0.55)
				_power_burst(e["ability_id"], square_to_world(e["target"]), col)
				await get_tree().create_timer(0.55).timeout
				if camera_rig != null:
					camera_rig.reset_view(true)
			"shield":
				Effects.pillar(_fx_root, square_to_world(e["square"]), Style.power_color("royal_decree"), 3.0, 0.7)
			"brace":
				Effects.ring(_fx_root, square_to_world(e["square"]), Style.power_color("brace"), 1.0)
			"toil":
				Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.4, 0), Style.CRYSTAL, 40, 3.0)
			"heal":
				Effects.pillar(_fx_root, square_to_world(e["square"]), Color(0.5, 1.0, 0.5), 2.5, 0.7)
				_float_text(square_to_world(e["square"]), "+%d" % e["amount"], Color(0.5, 1.0, 0.5))
			"freeze":
				Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.5, 0), Color(0.8, 0.95, 1.0), 24, 2.5)
				if e.get("damage", 0) > 0:
					_float_text(square_to_world(e["square"]), str(e["damage"]), Color(0.7, 0.9, 1.0))
			"lava":
				Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.2, 0), Style.LAVA, 20, 3.0)
			"burn":
				_float_text(square_to_world(e["square"]), str(e["damage"]), Style.LAVA)
			"tower_shot":
				if is_visible_square(e["to"]):
					await _arrow(square_xz(e["from"]) + Vector3(0, 2.0, 0), square_to_world(e["to"]) + Vector3(0, 0.6, 0))
					_float_text(square_to_world(e["to"]), str(e["damage"]), Color(1.0, 0.4, 0.3))
			"destroyed":
				if camera_rig != null:
					camera_rig.shake(0.2, 0.4)
				Effects.shockwave(_fx_root, square_xz(e["square"]), Color(0.7, 0.65, 0.6), 2.5)
			"energy":
				_energy_sparkles(state, e["color"])
	sync(state)
	presentation_done.emit()


## A bolt flying from a tower to its target.
func _arrow(from: Vector3, to: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var c := SphereMesh.new()
	c.radius = 0.09
	c.height = 0.18
	mi.mesh = c
	mi.material_override = Style.glow(Color(1.0, 0.85, 0.5), 2.0)
	mi.position = from
	_fx_root.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", to, 0.35)
	await tw.finished
	Effects.burst(_fx_root, to, Color(1.0, 0.8, 0.4), 12, 2.0)
	mi.queue_free()


func _float_text(pos: Vector3, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = PERCENT_FONT
	l.font_size = 72
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 16
	l.outline_modulate = Color(0.05, 0.02, 0.02)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 1.5, 0)
	_fx_root.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector3(0, 0.8, 0), 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.9).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)


## The big moment of each power, at its target.
func _power_burst(id: String, at: Vector3, col: Color) -> void:
	match id:
		"frost":
			Effects.storm(_fx_root, at, Color(0.8, 0.95, 1.0), 1.6, 80)
			Effects.shockwave(_fx_root, at, Style.ICE, 2.2)
		"fire_breath":
			Effects.storm(_fx_root, at, Style.LAVA, 1.4, 70)
			Effects.shockwave(_fx_root, at, Style.LAVA, 2.0)
			if camera_rig != null:
				camera_rig.shake(0.15, 0.4)
		"royal_decree", "brace":
			Effects.shockwave(_fx_root, at, col, 1.8)
		"toil":
			Effects.pillar(_fx_root, at, Style.CRYSTAL, 4.0, 0.8)
		_:
			Effects.burst(_fx_root, at + Vector3(0, 0.5, 0), col, 40, 3.0)


## Little crystal sparks over the miners that just produced energy.
func _energy_sparkles(state: GameState, color: int) -> void:
	for s in Chess.N:
		var p := state.piece_at(s)
		if p != null and p.color == color and p.kind == Chess.Kind.MINER and is_visible_square(s):
			Effects.burst(_fx_root, square_to_world(s) + Vector3(0, 0.9, 0), Style.CRYSTAL, 8, 1.2, 0.05)
