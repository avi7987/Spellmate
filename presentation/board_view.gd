class_name BoardView
extends Node3D
## Draws the board, the characters, highlights and effects, and plays the
## animations for every action. It only READS the GameState; changes always go
## through GameController.

## square = the character clicked (or the ground square); ground = the square under the cursor.
signal square_clicked(square: int, ground: int)
signal presentation_done

const TILE_HEIGHT := 0.2

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


static func square_to_world(s: int) -> Vector3:
	return Vector3(Chess.file_of(s) - 3.5, TILE_HEIGHT * 0.5, 3.5 - Chess.rank_of(s))


static func world_to_square(p: Vector3) -> int:
	var f := floori(p.x + 4.0)
	var r := floori(4.0 - p.z)
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

	_add_box(Vector3(9.3, 0.3, 9.3), Vector3(0, -0.2, 0), Style.matte(Style.FRAME_WOOD))
	_add_box(Vector3(8.5, 0.32, 8.5), Vector3(0, -0.15, 0), Style.metal(Style.FRAME_GOLD))
	# A glowing strip around the squares: its colour shows whose turn it is.
	_accent_mat = StandardMaterial3D.new()
	_accent_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_accent_mat.albedo_color = Style.MOOD[Chess.WHITE]["accent"]
	for side in [[Vector3(8.16, 0.04, 0.08), Vector3(0, 0.02, 4.04)], [Vector3(8.16, 0.04, 0.08), Vector3(0, 0.02, -4.04)],
			[Vector3(0.08, 0.04, 8.16), Vector3(4.04, 0.02, 0)], [Vector3(0.08, 0.04, 8.16), Vector3(-4.04, 0.02, 0)]]:
		_add_box(side[0], side[1], _accent_mat)
	for s in 64:
		var light := Chess.is_light_square(s)
		var c: Color = Style.TILE_LIGHT if light else Style.TILE_DARK
		# Slight colour variation per tile makes the stone feel hand-made.
		var n := (sin(s * 12.9898) * 43758.5453)
		c = c.darkened((n - floorf(n)) * 0.06)
		var tile := _add_box(Vector3(0.98, TILE_HEIGHT, 0.98), Vector3(square_to_world(s).x, 0, square_to_world(s).z),
			Style.matte(c))
		_tiles.append(tile)
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
	for i in 8:
		_coord_label(Chess.FILES[i], Vector3(i - 3.5, 0.02, 4.42))
		_coord_label(str(i + 1), Vector3(-4.42, 0.02, 3.5 - i))


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
	var seen := {}
	for s in 64:
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
		v.set_status(state.is_shielded(p), state.is_frozen(p))
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


## Checkmate: the losing king falls, the winning side cheers.
func play_checkmate(state: GameState, loser: int) -> void:
	var king_sq := state.find_king(loser)
	for v in _pieces.values():
		var p := state.piece_at(v.square)
		if p != null and p.color != loser:
			v.play_action("victory", 1.0)
	var king: PieceView = null
	for v in _pieces.values():
		if v.square == king_sq:
			king = v
	if king == null:
		return
	var at := square_to_world(king_sq)
	Effects.square_flash(self, at, Color(1, 0.2, 0.1, 0.9), 0.6)
	Effects.burst(self, at + Vector3(0, 0.5, 0), Color(1.0, 0.3, 0.15), 40, 3.5)
	Effects.ring(self, at, Color(1, 0.25, 0.1, 1.0), 2.0, 0.7)
	if camera_rig != null:
		camera_rig.shake(0.12, 0.4)
	await king.fall()


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
		mi.position = square_to_world(s) + Vector3(0, 0.105, 0)
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
	mi.position = square_to_world(s) + Vector3(0, 0.102 + 0.001 * kind, 0)
	(parent if parent != null else _highlight_root).add_child(mi)


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
	var px_per_unit := get_viewport().get_visible_rect().size.y / cam.size
	var radius := 0.36 * px_per_unit
	var best := -1
	var best_y := -INF
	for v in _pieces.values():
		if not v.visible or v.square < 0:
			continue
		var seg: Array = v.screen_segment(cam)
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
	var captured_ids := {}
	for e in events:
		match e["type"]:
			"capture":
				captured_ids[e["piece_id"]] = e
	for e in events:
		match e["type"]:
			"move":
				var v := view_of(e["piece_id"])
				if v == null:
					continue
				var target := square_to_world(e["to"])
				var is_dragon: bool = v.kind == Chess.Kind.KNIGHT
				# If this move captures, the battle plays once the attacker arrives.
				var cap_event: Dictionary = {}
				for id in captured_ids:
					if captured_ids[id]["by_id"] == e["piece_id"]:
						cap_event = captured_ids[id]
				await v.move_to(target, 0.34, is_dragon)
				if not cap_event.is_empty():
					await combat.play_capture(v, view_of(cap_event["piece_id"]), square_to_world(cap_event["square"]))
			"promote":
				var pv := view_of(e["piece_id"])
				if pv != null:
					Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.5, 0), Color(1, 0.9, 0.4), 30)
					pv.set_kind(e["kind"])
					await pv.pop_in()
			"ability":
				var caster := view_of(e["piece_id"])
				Effects.ring(_fx_root, square_to_world(e["from"]), Style.HL_ABILITY, 1.4, 0.5)
				if caster != null:
					await caster.play_action("cast", 0.5)
			"shield":
				Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.5, 0), Color(0.5, 0.8, 1.0), 20, 2.0)
			"freeze":
				Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.5, 0), Color(0.8, 0.95, 1.0), 30, 2.5)
				Effects.ring(_fx_root, square_to_world(e["square"]), Style.ICE, 1.3)
			"lava":
				Effects.burst(_fx_root, square_to_world(e["square"]) + Vector3(0, 0.2, 0), Style.LAVA, 30, 3.0)
				if camera_rig != null:
					camera_rig.shake(0.05, 0.2)
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
						Effects.burst(_fx_root, v.position + Vector3(0, 0.5, 0), Style.HL_ABILITY, 20, 2.0)
				if a != null:
					a.position = square_to_world(e["to"])
					a.pop_in()
				if b != null:
					b.position = square_to_world(e["from"])
					await b.pop_in()
	sync(state)
	presentation_done.emit()
