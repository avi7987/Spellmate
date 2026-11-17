class_name BoardView
extends Node3D
## Draws the board, the characters, highlights and effects, and plays the
## animations for every action. It only READS the GameState; changes always go
## through GameController.

signal square_clicked(square: int)
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


func highlight_square(s: int, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(0.98, 0.98)
	mi.mesh = plane
	mi.material_override = Style.overlay(color)
	mi.position = square_to_world(s) + Vector3(0, 0.102, 0)
	_highlight_root.add_child(mi)


func highlight_dot(s: int, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.15
	c.bottom_radius = 0.15
	c.height = 0.02
	mi.mesh = c
	mi.material_override = Style.overlay(color)
	mi.position = square_to_world(s) + Vector3(0, 0.11, 0)
	_highlight_root.add_child(mi)


func highlight_ring(s: int, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.38
	t.outer_radius = 0.47
	mi.mesh = t
	mi.material_override = Style.overlay(color)
	mi.position = square_to_world(s) + Vector3(0, 0.11, 0)
	_highlight_root.add_child(mi)
	var tw := mi.create_tween().set_loops()
	tw.tween_property(mi, "scale", Vector3(1.06, 1, 1.06), 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.5).set_trans(Tween.TRANS_SINE)


# ------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var s := camera_rig.square_at_screen(event.position)
		if s >= 0:
			square_clicked.emit(s)
	elif event is InputEventScreenTouch and event.pressed:
		var s := camera_rig.square_at_screen(event.position)
		if s >= 0:
			square_clicked.emit(s)


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
