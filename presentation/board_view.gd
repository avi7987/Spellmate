class_name BoardView
extends Node3D
## Draws the board, the characters, highlights and effects, and plays the
## animations for every action. It only READS the GameState; changes always go
## through GameController.

## square = the character clicked (or the ground square); ground = the square under the cursor.
signal square_clicked(square: int, ground: int)
signal presentation_done
signal square_hovered(square: int)

const TILE_HEIGHT := 0.2
const HALF_W := (Chess.W - 1) / 2.0
const HALF_H := (Chess.H - 1) / 2.0

var combat: CombatDirector
var camera_rig: CameraRig

var _pieces: Dictionary = {}       # piece id -> PieceView
var _tiles: Array = []
var _highlight_root: Node3D
var _fx_root: Node3D
var _lava_root: Node3D
var _pieces_root: Node3D
var _facing_yaw := 0.0
var _scenery: Scenery
var _accent_mat: StandardMaterial3D
var _terrain_view: TerrainView
var _terrain: PackedInt32Array


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
	_build_board()
	_pieces_root = Node3D.new()
	add_child(_pieces_root)
	_highlight_root = Node3D.new()
	add_child(_highlight_root)
	_lava_root = Node3D.new()
	add_child(_lava_root)
	_fx_root = Node3D.new()
	add_child(_fx_root)


# ------------------------------------------------------------ board building

func _build_board() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	ground.material_override = Style.matte(Style.GRASS)
	ground.position = Vector3(0, -0.3, 0)
	add_child(ground)

	var fw := Chess.W + 1.3
	var fh := Chess.H + 1.3
	# Frame boxes stay below the river surface so the water shows.
	_add_box(Vector3(fw, 0.3, fh), Vector3(0, -0.36, 0), Style.matte(Style.FRAME_WOOD))
	_add_box(Vector3(Chess.W + 0.5, 0.1, Chess.H + 0.5), Vector3(0, -0.2, 0), Style.metal(Style.FRAME_GOLD))
	# A glowing strip around the battlefield: its colour shows whose turn it is.
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
	_build_coordinates()
	_scenery = Scenery.new()
	add_child(_scenery)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _build_coordinates() -> void:
	for i in Chess.W:
		_coord_label(Chess.FILES[i], Vector3(i - HALF_W, 0.02, Chess.H / 2.0 + 0.42))
	for i in Chess.H:
		_coord_label(str(i + 1), Vector3(-Chess.W / 2.0 - 0.42, 0.02, HALF_H - i))


## Builds the squares' terrain (once per battle; the map does not change).
func build_terrain(state: GameState) -> void:
	if _terrain == state.terrain:
		return
	_terrain = state.terrain
	_terrain_view.build(state.terrain)


func _coord_label(text: String, pos: Vector3) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 48
	l.pixel_size = 0.005
	l.modulate = Color(1.0, 0.92, 0.7)
	l.outline_modulate = Color(0.25, 0.14, 0.05)
	l.outline_size = 10
	l.position = pos
	l.rotation_degrees = Vector3(-90, 0, 0)
	l.set_meta("coord", true)
	add_child(l)


# ------------------------------------------------------------ pieces

func sync(state: GameState) -> void:
	build_terrain(state)
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
		v.visible = true
		v.scale = Vector3.ONE
		v.square = s
		v.position = square_to_world(s)
		v.set_facing(_facing_yaw)
		v.set_kind(p.kind)
		v.set_status(state.is_shielded(p) or state.is_braced(p), state.is_frozen(p))
	for id in _pieces.keys():
		if not seen.has(id):
			_pieces[id].queue_free()
			_pieces.erase(id)
	_sync_lava(state)


func set_facing(yaw: float) -> void:
	_facing_yaw = yaw
	_scenery.set_facing(yaw)
	for v in _pieces.values():
		var tw: Tween = v.create_tween()
		tw.tween_property(v, "rotation_degrees:y", yaw, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	for c in get_children():
		if c is Label3D and c.has_meta("coord"):
			c.rotation_degrees = Vector3(-90, yaw, 0)


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
		var mat := Style.glow(Style.LAVA, 1.6)
		mi.material_override = mat
		mi.position = square_to_world(s) + Vector3(0, 0.005, 0)
		_lava_root.add_child(mi)
		var embers := CPUParticles3D.new()
		embers.amount = 10
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
		var tw := mi.create_tween().set_loops()
		tw.tween_property(mi, "scale", Vector3(0.92, 1, 0.92), 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(mi, "scale", Vector3.ONE, 0.6).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------ highlights

func clear_highlights() -> void:
	for c in _highlight_root.get_children():
		c.queue_free()


enum Mark { MOVE, CAPTURE, POWER, SELECTED, HOVER, LAST, CHECK }

const PERCENT_FONT := preload("res://assets/fonts/SuezOne.ttf")

const HIGHLIGHT_SHADER := preload("res://presentation/shaders/highlight.gdshader")


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
	mi.position = square_to_world(s) + Vector3(0, 0.002 + 0.001 * kind, 0)
	(parent if parent != null else _highlight_root).add_child(mi)


## A win-chance label floating on an attack target, e.g. "65%".
func mark_text(s: int, text: String, color: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font = PERCENT_FONT
	l.font_size = 64
	l.pixel_size = 0.0055
	l.modulate = color
	l.outline_modulate = Color(0.05, 0.02, 0.02)
	l.outline_size = 16
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.render_priority = 10
	l.position = square_to_world(s) + Vector3(0, 0.25, 0.32)
	_highlight_root.add_child(l)


var _hover_root: Node3D
var _hover_square := -1
var hover_enabled := true


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


## Characters lean up the screen, so a click on a character's body or head
## selects that character's square. Otherwise the square under the cursor.
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
			# Front-most character wins (the one standing lower on the screen).
			if seg[0].y > best_y:
				best_y = seg[0].y
				best = v.square
	if best >= 0:
		return best
	return camera_rig.square_at_screen(pos)


# ------------------------------------------------------------ playing actions

## Animates what happened, then makes the view match the new state exactly.
func play_events(events: Array, state: GameState) -> void:
	var skip_moves := {}   # moves/deaths already shown as part of a battle
	for e in events:
		match e["type"]:
			"battle":
				var a := view_of(e["attacker_id"])
				var d := view_of(e["defender_id"])
				skip_moves[e["attacker_id"]] = true
				await combat.play_battle(e, a, d, square_to_world(e["from"]), square_to_world(e["to"]), _terrain[e["to"]])
			"move":
				if skip_moves.has(e["piece_id"]):
					continue
				var v := view_of(e["piece_id"])
				if v != null:
					await v.move_to(square_to_world(e["to"]), 0.34, v.kind == Chess.Kind.KNIGHT)
			"ability":
				# A short cinematic: the camera swoops in, the hero casts, a big effect.
				var caster := view_of(e["piece_id"])
				var at := square_to_world(e["from"])
				var col := Style.power_color(e["ability_id"])
				if camera_rig != null:
					await camera_rig.focus(at, 6.5, 0.45)
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
			"freeze":
				Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.5, 0), Color(0.8, 0.95, 1.0), 24, 2.5)
			"lava":
				Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.2, 0), Style.LAVA, 20, 3.0)
			"push":
				var pushed := view_of(e["piece_id"])
				if pushed != null:
					Effects.burst(_fx_root, square_to_world(e["from"]) + Vector3(0, 0.2, 0), Color(0.7, 0.65, 0.6), 18, 2.0)
					await pushed.move_to(square_to_world(e["to"]), 0.22)
			"swap":
				var a := view_of(e["piece_id"])
				var b := view_of(e["other_id"])
				for v in [a, b]:
					if v != null:
						Effects.burst(_fx_root, v.position + Vector3(0, 0.5, 0), Style.power_color("swap"), 20, 2.0)
				if a != null:
					a.position = square_to_world(e["to"])
					a.pop_in()
				if b != null:
					b.position = square_to_world(e["from"])
					await b.pop_in()
			"energy":
				_energy_sparkles(state, e["color"])
	sync(state)
	presentation_done.emit()


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
		"stone_push":
			Effects.shockwave(_fx_root, at, Color(0.75, 0.65, 0.5), 2.5)
			if camera_rig != null:
				camera_rig.shake(0.2, 0.35)
		"swap":
			Effects.pillar(_fx_root, at, col, 5.0, 0.8)
			Effects.burst(_fx_root, at + Vector3(0, 0.6, 0), col, 50, 3.0)
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
		if p != null and p.color == color and p.kind == Chess.Kind.MINER:
			Effects.burst(_fx_root, square_to_world(s) + Vector3(0, 0.9, 0), Style.CRYSTAL, 8, 1.2, 0.05)
