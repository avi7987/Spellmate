class_name BattleView
extends Node3D
## Draws a real-time battle: the map, palaces (gate, king), heroes, shots,
## spells, numbers, the fog of war, selection rings, order markers, the squares
## a chosen hero can reach this turn (chess-like) and the goal of the game mode
## (a crown, a throne, magic runes, or the threatened squares around a king).
## It only READS the Battle; orders go through game/battle_main.gd.

const ENV_DIR := "res://assets/environment/kaykit/"
var PERCENT_FONT: Font = UiKit.font(700)

var battle: Battle
var viewer := 0
var camera_rig: CameraRig

var _terrain_view: TerrainView
var _units_root: Node3D
var _fx_root: Node3D
var _views: Dictionary = {}       ## unit id -> UnitView or structure Node3D
var _selected: Array = []
var _fog: MultiMeshInstance3D
var _fog_timer := 0.0
var _target_circle: MeshInstance3D
var _w := 0
var _h := 0


func setup(b: Battle, p_viewer: int) -> void:
	battle = b
	viewer = p_viewer
	_w = b.w
	_h = b.h
	for c in get_children():
		c.queue_free()
	_views.clear()
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(220, 220)
	ground.mesh = plane
	var rim := Color.html(b.world.get("colors", {}).get("rim", "#2b3d22"))
	ground.material_override = Style.matte(rim)
	ground.position = Vector3(0, -0.4, 0)
	add_child(ground)
	var frame := MeshInstance3D.new()
	var fb := BoxMesh.new()
	fb.size = Vector3(_w + 1.0, 0.3, _h + 1.0)
	frame.mesh = fb
	frame.material_override = Style.matte(Style.FRAME_WOOD)
	frame.position = Vector3(0, -0.3, 0)
	add_child(frame)
	_terrain_view = TerrainView.new()
	add_child(_terrain_view)
	_terrain_view.build(b.map["terrain"], _w, _h, b.world)
	_scenery()
	_shrines()
	_objectives()
	_units_root = Node3D.new()
	add_child(_units_root)
	_fx_root = Node3D.new()
	add_child(_fx_root)
	_target_circle = MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.94
	t.outer_radius = 1.0
	t.rings = 48
	_target_circle.mesh = t
	_target_circle.visible = false
	_target_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_target_circle)
	if b.map["fog"]:
		_build_fog()
	for u: BUnit in b.units:
		_add_view(u, false)


## Map position (x, y in squares) -> world point on top of the ground.
func to_world(p: Vector2) -> Vector3:
	var c := Vector2i(clampi(roundi(p.x), 0, _w - 1), clampi(roundi(p.y), 0, _h - 1))
	var t: int = battle.map["terrain"][c.y * _w + c.x]
	var top := TerrainView.top_of(t if t != Chess.Terrain.WALL else Chess.Terrain.PLAIN)
	return Vector3(p.x - (_w - 1) / 2.0, top, (_h - 1) / 2.0 - p.y)


func to_map(world: Vector3) -> Vector2:
	return Vector2(world.x + (_w - 1) / 2.0, (_h - 1) / 2.0 - world.z)


## The map point under the mouse.
func ground_at_screen(screen: Vector2) -> Vector2:
	var cam := get_viewport().get_camera_3d()
	var o := cam.project_ray_origin(screen)
	var d := cam.project_ray_normal(screen)
	if absf(d.y) < 0.0001:
		return Vector2(-99, -99)
	var hit := o + d * ((0.1 - o.y) / d.y)
	return to_map(hit)


## The unit under the mouse (its body, since characters stand up), or -1.
func unit_at_screen(screen: Vector2, max_px: float = 26.0) -> int:
	var cam := get_viewport().get_camera_3d()
	var best := -1
	var best_d := max_px
	for id in _views:
		var v = _views[id]
		if not is_instance_valid(v) or (v is UnitView and v.dying):
			continue
		var u := battle.unit(id)
		if u == null or (u.team != viewer and not battle.is_visible(viewer, u.pos)):
			continue
		var d := INF
		if v is UnitView:
			var seg: Array = v.screen_segment(cam)
			d = Geometry2D.get_closest_point_to_segment(screen, seg[0], seg[1]).distance_to(screen)
		else:
			var c := cam.unproject_position(v.global_position + Vector3(0, 0.8, 0))
			d = c.distance_to(screen) * 0.6
		if d < best_d:
			best_d = d
			best = id
	return best


## Own heroes whose feet are inside a screen rectangle (drag selection).
func units_in_rect(rect: Rect2) -> Array:
	var cam := get_viewport().get_camera_3d()
	var out := []
	for u: BUnit in battle.units:
		if u.team != viewer or u.structure or u.kind == "king" or not _views.has(u.id):
			continue
		var v: Node3D = _views[u.id]
		if rect.has_point(cam.unproject_position(v.global_position + Vector3(0, 0.4, 0))):
			out.append(u.id)
	return out


func view(id: int) -> Node3D:
	return _views.get(id, null)


func set_selection(ids: Array) -> void:
	for id in _selected:
		var v = _views.get(id, null)
		if v is UnitView and is_instance_valid(v):
			v.set_selected(false)
	_selected = ids.duplicate()
	for id in _selected:
		var v = _views.get(id, null)
		if v is UnitView:
			v.set_selected(true)


## A circle on the ground showing where a power or spell will land.
func show_target_circle(pos: Vector2, radius: float, color: Color) -> void:
	_target_circle.visible = true
	_target_circle.position = to_world(pos) + Vector3(0, 0.08, 0)
	_target_circle.scale = Vector3(radius, 0.4, radius)
	_target_circle.material_override = Style.glow(color, 1.5)


func hide_target_circle() -> void:
	_target_circle.visible = false


var _range_circle: MeshInstance3D


## A thin circle around a hero showing how far its power reaches.
func show_range_circle(center: Vector2, radius: float) -> void:
	if _range_circle == null:
		_range_circle = MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.97
		t.outer_radius = 1.0
		t.rings = 64
		_range_circle.mesh = t
		_range_circle.material_override = Style.glow(Color(1.0, 0.9, 0.6), 1.0)
		_range_circle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_range_circle)
	_range_circle.visible = true
	_range_circle.position = to_world(center) + Vector3(0, 0.07, 0)
	_range_circle.scale = Vector3(radius, 0.3, radius)


func hide_range_circle() -> void:
	if _range_circle != null:
		_range_circle.visible = false


## A planned card or power: a pulsing ring with a label until the turn starts.
func plan_marker(pos: Vector2, radius: float, color: Color, text: String) -> Node3D:
	var root := Node3D.new()
	root.position = to_world(pos) + Vector3(0, 0.08, 0)
	add_child(root)
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 48
	ring.mesh = t
	ring.scale = Vector3(radius, 0.4, radius)
	ring.material_override = Style.glow(color, 1.6)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(ring)
	var disc := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.01
	disc.mesh = c
	disc.material_override = Style.overlay(Color(color.r, color.g, color.b, 0.18))
	root.add_child(disc)
	var l := Label3D.new()
	l.text_direction = TextServer.DIRECTION_RTL
	l.text = text
	l.font = UiKit.font(700)
	l.font_size = 46
	l.outline_size = 12
	l.outline_modulate = UiKit.OUTLINE
	l.modulate = UiKit.TEXT
	l.pixel_size = 0.008
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = Vector3(0, 1.0, 0)
	root.add_child(l)
	var tw := ring.create_tween().set_loops()
	tw.tween_property(ring, "scale", Vector3(radius * 1.08, 0.4, radius * 1.08), 0.5)
	tw.tween_property(ring, "scale", Vector3(radius, 0.4, radius), 0.5)
	return root


## A little arrow/ring where the player sent units.
func order_marker(pos: Vector2, attack: bool) -> void:
	Effects.ring(_fx_root, to_world(pos) + Vector3(0, 0.08, 0), Color(1, 0.3, 0.2) if attack else Color(0.5, 1.0, 0.5), 0.6, 0.45)


# ------------------------------------------------------------------ every frame

func _process(delta: float) -> void:
	if battle == null:
		return
	var now := battle.time
	for u: BUnit in battle.units:
		if not _views.has(u.id):
			_add_view(u, true)
		var v = _views[u.id]
		var seen := u.team == viewer or battle.is_visible(viewer, u.pos)
		if u.team != viewer and u.style() == "stealth" and battle.time <= u.revealed_until:
			pass
		elif u.team != viewer and u.style() == "stealth":
			var near := false
			for f: BUnit in battle.units:
				if f.team == viewer and not f.structure and f.pos.distance_to(u.pos) <= 1.6:
					near = true
					break
			seen = seen and near
		if v is UnitView:
			v.visible = seen
			v.follow(u, to_world(u.pos), now, delta)
		elif v.has_meta("bar"):
			v.get_meta("bar").set_health(int(u.hp), int(u.max_hp))
	_update_objectives(delta)
	if _fog != null:
		_fog_timer -= delta
		if _fog_timer <= 0.0:
			_fog_timer = 0.2
			_update_fog()


func _add_view(u: BUnit, animate: bool) -> void:
	var v: Node3D
	if u.structure:
		v = _build_structure(u)
	else:
		var uv := UnitView.new()
		_units_root.add_child(uv)
		uv.setup(u)
		uv.position = to_world(u.pos)
		if animate:
			uv.pop_in()
			Effects.ring(_fx_root, uv.position + Vector3(0, 0.1, 0), Style.team(u.team)["ui"], 1.0, 0.5)
		v = uv
	_views[u.id] = v


func _build_structure(u: BUnit) -> Node3D:
	var root := Node3D.new()
	_units_root.add_child(root)
	root.position = to_world(u.pos)
	var stone := Style.matte(Color(0.42, 0.41, 0.42))
	var team_col: Color = Style.team(u.team)["ui"]
	var bar_h := 2.2
	match u.kind:
		"gate":
			root.position.y = TerrainView.top_of(Chess.Terrain.PLAIN)
			for x in [-0.45, 0.45]:
				_box(root, Vector3(0.24, 1.5, 1.0), Vector3(x, 0.75, 0), stone)
				_box(root, Vector3(0.3, 0.2, 1.05), Vector3(x, 1.6, 0), stone)
			_box(root, Vector3(1.1, 0.25, 1.0), Vector3(0, 1.45, 0), stone)
			_box(root, Vector3(0.68, 1.1, 0.16), Vector3(0, 0.55, 0), Style.toon(Color(0.36, 0.22, 0.12), 0.0, 0.9))
			for y in [0.25, 0.75]:
				_box(root, Vector3(0.7, 0.06, 0.2), Vector3(0, y, 0), Style.metal(Style.team(u.team)["metal"]))
			_box(root, Vector3(0.5, 0.55, 0.04), Vector3(0, 1.15, 0.53 if u.team == 0 else -0.53), Style.cloth(team_col.darkened(0.3)))
		"tower":
			root.position.y = TerrainView.top_of(Chess.Terrain.WALL) - 0.1
			var path := ENV_DIR + ("building_tower_A_blue" if u.team == 0 else "building_tower_A_red") + ".gltf"
			if ResourceLoader.exists(path):
				var tower := (load(path) as PackedScene).instantiate() as Node3D
				tower.scale = Vector3.ONE * 0.6
				root.add_child(tower)
			bar_h = 2.4
		"wall":
			root.position.y = TerrainView.top_of(Chess.Terrain.PLAIN)
			for i in 3:
				var s := MeshInstance3D.new()
				var cyl := CylinderMesh.new()
				cyl.top_radius = 0.22
				cyl.bottom_radius = 0.3
				cyl.height = 0.9
				s.mesh = cyl
				s.material_override = Style.metal(Style.team(u.team)["metal"])
				s.position = Vector3(-0.32 + i * 0.32, 0.45, 0)
				root.add_child(s)
			_box(root, Vector3(1.0, 0.12, 0.2), Vector3(0, 0.75, 0.1), Style.glow(team_col, 1.4))
			bar_h = 1.4
			root.scale = Vector3(0.01, 0.01, 0.01)
			root.create_tween().tween_property(root, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bar := HealthBar3D.new()
	bar.position = Vector3(0, bar_h, 0)
	bar.bar_color = team_col
	root.add_child(bar)
	bar.set_health(int(u.hp), int(u.max_hp))
	root.set_meta("bar", bar)
	return root


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)


## Flags on the palace walls and a few props, so each kingdom feels like home.
func _scenery() -> void:
	for team in 2:
		var p: Dictionary = battle.map["palaces"][team]
		var f: Rect2i = p["floor"]
		var flag := ENV_DIR + ("flag_blue" if team == 0 else "flag_red") + ".gltf"
		if ResourceLoader.exists(flag):
			for corner in [Vector2(f.position.x - 1, f.position.y if team == 1 else f.end.y), Vector2(f.end.x, f.position.y if team == 1 else f.end.y)]:
				var n := (load(flag) as PackedScene).instantiate() as Node3D
				n.position = to_world(corner) + Vector3(0, TerrainView.top_of(Chess.Terrain.WALL) - 0.1, 0)
				n.scale = Vector3.ONE * 0.5
				add_child(n)
		for prop in ["barrel", "crate_A_big"]:
			var path: String = ENV_DIR + prop + ".gltf"
			if ResourceLoader.exists(path):
				var n := (load(path) as PackedScene).instantiate() as Node3D
				var spot := Vector2(f.position.x + (0 if prop == "barrel" else f.size.x - 1), f.position.y + (0 if team == 0 else f.size.y - 1))
				n.position = to_world(spot) + Vector3(0, 0, 0)
				n.scale = Vector3.ONE * 0.45
				add_child(n)


# ------------------------------------------------------------------ plan lines

var _plan_lines: MeshInstance3D
var _reach_rings: Array = []


## While planning: an arrow from every hero you gave an order to where it is
## going (green = walk, red = attack), and for the chosen heroes a ring that
## shows how far they can walk in one turn.
func draw_plans(selected: Array, turn_seconds: float, hover: Vector2i = Vector2i(-99, -99)) -> void:
	if _plan_lines == null:
		_plan_lines = MeshInstance3D.new()
		_plan_lines.mesh = ImmediateMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.no_depth_test = true
		_plan_lines.material_override = m
		_plan_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_plan_lines)
	_plan_lines.visible = true
	var im := _plan_lines.mesh as ImmediateMesh
	im.clear_surfaces()
	var any := false
	for u: BUnit in battle.units:
		if u.team != viewer or u.structure:
			continue
		var goal := Vector2(-1, -1)
		var col := Color(0.45, 1.0, 0.45, 0.9)
		if u.order == "move":
			goal = u.order_pos
		elif u.order == "attack" and battle.unit(u.target_id) != null:
			goal = battle.unit(u.target_id).pos
			col = Color(1.0, 0.35, 0.25, 0.95)
		if goal.x < 0:
			continue
		if not any:
			im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
			any = true
		var a := to_world(u.pos) + Vector3(0, 0.12, 0)
		var b := to_world(goal) + Vector3(0, 0.12, 0)
		var dir := (b - a)
		if dir.length() < 0.3:
			continue
		var n := dir.normalized()
		var side := Vector3(-n.z, 0, n.x) * (0.09 if u.id in selected else 0.06)
		var tip := b - n * 0.45
		for t in [[a - side, a + side, tip + side], [a - side, tip + side, tip - side],
				[tip - side * 3.5, tip + side * 3.5, b]]:
			for v in t:
				im.surface_set_color(col)
				im.surface_add_vertex(v)
	if any:
		im.surface_end()
	_draw_tiles(selected[0] if selected.size() == 1 else -1, hover)


var _tile_mesh: MeshInstance3D
var reach_now: Dictionary = {}       ## the squares the chosen hero can reach (for clicks)
var attack_now: Array = []           ## enemy ids the chosen hero can hit this turn


## Lights the squares the chosen hero can walk to this turn (gold), the enemies
## it can hit (red), the square under the mouse, and in "mate" the threatened
## squares around both kings.
func _draw_tiles(id: int, hover: Vector2i) -> void:
	if _tile_mesh == null:
		_tile_mesh = MeshInstance3D.new()
		_tile_mesh.mesh = ImmediateMesh.new()
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_tile_mesh.material_override = m
		_tile_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_tile_mesh)
	_tile_mesh.visible = true
	var im := _tile_mesh.mesh as ImmediateMesh
	im.clear_surfaces()
	reach_now = {}
	attack_now = []
	var quads := []      # [cell, colour, inset]
	var u := battle.unit(id) if id >= 0 else null
	if u != null:
		reach_now = battle.reach_cells(u, true)
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 250.0)
		for c in reach_now:
			if c == u.cell():
				continue
			var col := Color(1.0, 0.82, 0.3, 0.30)
			if c == hover:
				col = Color(1.0, 0.92, 0.5, 0.65 + 0.2 * pulse)
			quads.append([c, col, 0.06])
		for e: BUnit in battle.attackable(u, true):
			if e.team == viewer or (e.team != Battle.NEUTRAL and not battle.is_visible(viewer, e.pos)):
				continue
			attack_now.append(e.id)
			var hot: bool = e.cell() == hover
			quads.append([e.cell(), Color(1.0, 0.22, 0.18, (0.7 if hot else 0.45) + 0.15 * pulse), 0.02])
		quads.append([u.cell(), Color(0.5, 1.0, 0.5, 0.35), 0.1])
	if battle.mode == "mate":
		for team in 2:
			for c in battle.mate_cells[team]:
				quads.append([c, Color(1.0, 0.3, 0.2, 0.35) if team == 1 else Color(1.0, 0.55, 0.1, 0.35), 0.18])
	if quads.is_empty():
		return
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for q in quads:
		var c: Vector2i = q[0]
		var col: Color = q[1]
		var k: float = 0.5 - q[2]
		var center := to_world(Vector2(c)) + Vector3(0, 0.07, 0)
		var a := center + Vector3(-k, 0, -k)
		var b := center + Vector3(k, 0, -k)
		var cc := center + Vector3(k, 0, k)
		var d := center + Vector3(-k, 0, k)
		for v in [a, b, cc, a, cc, d]:
			im.surface_set_color(col)
			im.surface_add_vertex(v)
		# a brighter rim
		var rim := Color(col.r, col.g, col.b, minf(1.0, col.a + 0.35))
		var t := 0.05
		for e in [[a, b, Vector3(0, 0, t)], [b, cc, Vector3(-t, 0, 0)], [cc, d, Vector3(0, 0, -t)], [d, a, Vector3(t, 0, 0)]]:
			var p0: Vector3 = e[0]
			var p1: Vector3 = e[1]
			var o: Vector3 = e[2]
			for v in [p0, p1, p1 + o, p0, p1 + o, p0 + o]:
				im.surface_set_color(rim)
				im.surface_add_vertex(v)
	im.surface_end()


func hide_plans() -> void:
	if _plan_lines != null:
		_plan_lines.visible = false
	reach_now = {}
	attack_now = []
	if _tile_mesh != null:
		if battle.mode == "mate":
			_draw_tiles(-1, Vector2i(-99, -99))
		else:
			_tile_mesh.visible = false


# ------------------------------------------------------------------ world things

var _treasures: Dictionary = {}


## Shrines: a healing spring (glowing basin), a power stone (red rune) and a
## magic well (a ring of stones with a floating crystal).
func _shrines() -> void:
	var stone := Style.toon(Color(0.55, 0.53, 0.5), 0.0, 0.9)
	for sh in battle.map.get("shrines", []):
		var root := Node3D.new()
		root.position = to_world(Vector2(sh["pos"]))
		add_child(root)
		match sh["type"]:
			"heal":
				_part(root, _cyl_mesh(0.42, 0.48, 0.2), stone, Vector3(0, 0.1, 0))
				_part(root, _cyl_mesh(0.34, 0.34, 0.04), Style.glow(Color(0.45, 1.0, 0.6), 1.6), Vector3(0, 0.21, 0))
			"power":
				_part(root, _box_mesh(Vector3(0.35, 0.9, 0.25)), stone, Vector3(0, 0.45, 0), Vector3(0, 0, 4))
				_part(root, _box_mesh(Vector3(0.14, 0.3, 0.02)), Style.glow(Color(1.0, 0.3, 0.2), 2.2), Vector3(0, 0.55, 0.13))
			"energy":
				for i in 6:
					var a := TAU * i / 6.0
					_part(root, _box_mesh(Vector3(0.14, 0.25, 0.14)), stone, Vector3(cos(a) * 0.38, 0.12, sin(a) * 0.38))
				var crystal := _part(root, _cyl_mesh(0.0, 0.14, 0.4), Style.glow(Style.CRYSTAL, 2.4), Vector3(0, 0.75, 0))
				crystal.create_tween().set_loops().tween_property(crystal, "rotation_degrees:y", 360.0, 3.0).from(0.0)
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.95
		t.outer_radius = 1.0
		ring.mesh = t
		var r := float(BattleData.biomes()["shrines"][sh["type"]].get("radius", 1.6))
		ring.scale = Vector3(r, 0.3, r)
		ring.position.y = 0.06
		ring.material_override = Style.glow({"heal": Color(0.45, 1, 0.6), "power": Color(1, 0.35, 0.25), "energy": Style.CRYSTAL}[sh["type"]], 0.8)
		root.add_child(ring)


func _part(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _cyl_mesh(top: float, bottom: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top
	c.bottom_radius = bottom
	c.height = h
	c.radial_segments = 12
	return c


func _box_mesh(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _add_treasure(id: int, pos: Vector2) -> void:
	var path := "res://assets/props/chest_gold.glb"
	if not ResourceLoader.exists(path):
		return
	var n := (load(path) as PackedScene).instantiate() as Node3D
	n.position = to_world(pos)
	n.scale = Vector3.ONE * 0.01
	add_child(n)
	_treasures[id] = n
	n.create_tween().tween_property(n, "scale", Vector3.ONE * 0.75, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var bob := n.create_tween().set_loops()
	bob.tween_property(n, "rotation_degrees:y", 15.0, 0.8)
	bob.tween_property(n, "rotation_degrees:y", -15.0, 0.8)
	Effects.pillar(_fx_root, n.position, UiKit.GOLD, 3.0, 0.8)


# ------------------------------------------------------------------ events

func play_events(events: Array) -> void:
	for e in events:
		match e["type"]:
			"attack":
				_on_attack(e)
			"damage":
				var v = _views.get(e["id"], null)
				if v is UnitView and e["amount"] >= 20.0:
					v.play_once("hit")
					if _seen_id(e["id"]) and e["amount"] >= 40.0:
						_float_text(v.position, str(int(e["amount"])), Color(1.0, 0.85, 0.75), 0.7)
				elif v != null and not (v is UnitView) and e["amount"] >= 40.0:
					var tw: Tween = v.create_tween()
					tw.tween_property(v, "position:x", v.position.x + 0.05, 0.04)
					tw.tween_property(v, "position:x", v.position.x, 0.06)
			"heal":
				var v = _views.get(e["id"], null)
				if v != null and e["amount"] >= 5.0 and _seen_id(e["id"]):
					_float_text(v.position, "+%d" % int(e["amount"]), Color(0.45, 1.0, 0.5), 0.7)
			"death":
				_on_death(e)
			"energy":
				if e["id"] >= 0 and e["team"] == viewer:
					var v = _views.get(e["id"], null)
					if v != null:
						_float_text(v.position, "+1", Style.CRYSTAL, 0.8)
						Effects.burst(_fx_root, v.position + Vector3(0, 0.8, 0), Style.CRYSTAL, 8, 1.2, 0.05)
			"ability":
				var v = _views.get(e["id"], null)
				if v is UnitView:
					v.play_once("cast")
				_area_fx(e["ability"], e["pos"], e["radius"], e.get("from", e["pos"]))
			"spell":
				if e["card"] in ["ice_bomb", "fire_bomb", "heal_potion", "shield_wall"]:
					_spell_show(e["card"], e["pos"], e["radius"], e["team"])
				else:
					_area_fx(e["card"], e["pos"], e["radius"], e["pos"])
			"breach":
				_terrain_view.build(battle.map["terrain"], _w, _h, battle.world)
			"treasure_spawn":
				_add_treasure(e["id"], e["pos"])
			"treasure":
				var n = _treasures.get(e["id"], null)
				_treasures.erase(e["id"])
				if n != null:
					Effects.burst(_fx_root, n.position + Vector3(0, 0.5, 0), UiKit.GOLD, 30, 2.5)
					_float_text(n.position, "+%d ◆" % int(BattleData.biomes()["treasure"]["energy"]), Style.CRYSTAL, 1.0)
					var tw: Tween = n.create_tween()
					tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
					tw.tween_callback(n.queue_free)
			"shrine":
				Effects.burst(_fx_root, to_world(e["pos"]) + Vector3(0, 1.0, 0), Style.CRYSTAL, 10, 1.4, 0.05)
				if e["team"] == viewer:
					_float_text(to_world(e["pos"]), "+1 ◆", Style.CRYSTAL, 0.8)
			"chain":
				_shot(to_world(e["from"]) + Vector3(0, 0.8, 0), to_world(e["to"]) + Vector3(0, 0.6, 0), Color(0.75, 0.85, 1.0), 0.1, false)
			"trait":
				if e.get("trait", "") == "momentum":
					Effects.shockwave(_fx_root, to_world(e["pos"]) + Vector3(0, 0.05, 0), Color(1, 0.9, 0.5), 1.2)
			"monster_slain":
				Effects.pillar(_fx_root, to_world(e["pos"]), UiKit.GOLD, 4.0, 0.9)
				_float_text(to_world(e["pos"]), "+%d ◆" % int(BattleData.biomes()["monster_reward"]["energy"]), Style.CRYSTAL, 1.2)
			"upgrade":
				for u: BUnit in battle.units:
					if u.team == e["team"] and (u.kind == "tower" or u.kind == "gate") and _views.has(u.id):
						Effects.pillar(_fx_root, _views[u.id].position, Style.team(u.team)["ui"], 4.0, 0.8)


func _seen_id(id: int) -> bool:
	var u := battle.unit(id)
	return u != null and (u.team == viewer or battle.is_visible(viewer, u.pos))


func _on_attack(e: Dictionary) -> void:
	var a := battle.unit(e["id"])
	var t := battle.unit(e["target"])
	var av = _views.get(e["id"], null)
	if a == null or t == null or av == null:
		return
	if av is UnitView:
		av.play_once("attack")
	if not e.get("ranged", false):
		return
	if not (_seen_id(a.id) or _seen_id(t.id)):
		return
	var from: Vector3 = av.position + Vector3(0, 0.9 if not a.structure else 2.0, 0)
	var to := to_world(t.pos) + Vector3(0, 0.6, 0)
	var col := Color(1.0, 0.9, 0.6)
	var size := 0.07
	if e.get("heal", false):
		col = Color(0.45, 1.0, 0.5)
		size = 0.1
	else:
		match a.kind:
			"queen", "ice_witch":
				col = Color(0.6, 0.9, 1.0)
				size = 0.12
			"fire_mage", "dragon":
				col = Style.LAVA
				size = 0.14
			"ballista":
				size = 0.11
	_shot(from, to, col, size, a.kind in ["archer", "tower", "ballista"])


func _shot(from: Vector3, to: Vector3, col: Color, size: float, arc: bool) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = size
	s.height = size * 2.0
	mi.mesh = s
	mi.material_override = Style.glow(col, 2.0)
	mi.position = from
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fx_root.add_child(mi)
	var dur := clampf(from.distance_to(to) * 0.07, 0.12, 0.4)
	var tw := mi.create_tween()
	var h := 0.8 if arc else 0.15
	tw.tween_method(func(k: float): mi.position = from.lerp(to, k) + Vector3(0, sin(k * PI) * h, 0), 0.0, 1.0, dur)
	tw.tween_callback(func():
		Effects.burst(_fx_root, to, col, 6, 1.4, 0.04)
		mi.queue_free())


func _on_death(e: Dictionary) -> void:
	var v = _views.get(e["id"], null)
	_views.erase(e["id"])
	_selected.erase(e["id"])
	if v == null:
		return
	if v is UnitView:
		v.die()
		Effects.burst(_fx_root, v.position + Vector3(0, 0.5, 0), Style.team(e["team"])["ui"], 18, 2.2)
	else:
		Effects.burst(_fx_root, v.position + Vector3(0, 1.0, 0), Color(0.6, 0.55, 0.5), 40, 3.2, 0.12)
		Effects.shockwave(_fx_root, v.position, Color(0.8, 0.7, 0.6, 0.6), 2.0)
		if camera_rig:
			camera_rig.shake(0.2, 0.45)
		var tw: Tween = v.create_tween().set_parallel(true)
		tw.tween_property(v, "scale", Vector3(1.2, 0.05, 1.2), 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(v.queue_free)


## The visual of every power and spell, by what it does.
func _area_fx(id: String, pos: Vector2, radius: float, from: Vector2) -> void:
	var at := to_world(pos)
	var d := BattleData.spell(id)
	if d.is_empty():
		for h in BattleData.hero_ids():
			for ab in BattleData.hero(h).get("abilities", []):
				if ab.get("id", "") == id:
					d = ab
	var effect: String = d.get("effect", "")
	var kind: String = d.get("type", "")
	Effects.shockwave(_fx_root, at + Vector3(0, 0.05, 0), _fx_color(id, effect, kind), radius)
	match kind:
		"area_damage", "dash":
			if effect == "freeze" or effect == "slow":
				Effects.storm(_fx_root, at, Color(0.8, 0.95, 1.0), radius, 70)
			elif effect == "burn" or id in ["meteor", "fire_bomb"]:
				Effects.storm(_fx_root, at, Style.LAVA, radius, 70)
				if camera_rig:
					camera_rig.shake(0.18, 0.4)
			else:
				Effects.burst(_fx_root, at + Vector3(0, 0.5, 0), _fx_color(id, effect, kind), 40, 3.0)
				if camera_rig and id in ["ground_smash", "piercing_bolt"]:
					camera_rig.shake(0.15, 0.3)
			if kind == "dash":
				var trail_from := to_world(from)
				for i in 6:
					Effects.burst(_fx_root, trail_from.lerp(at, i / 5.0) + Vector3(0, 0.4, 0), Color(1, 1, 1, 0.8), 4, 0.8, 0.05)
		"area_heal":
			Effects.pillar(_fx_root, at, Color(0.45, 1.0, 0.55), 4.0, 0.9)
			Effects.burst(_fx_root, at + Vector3(0, 0.5, 0), Color(0.6, 1.0, 0.6), 30, 2.0)
		"area_buff":
			Effects.pillar(_fx_root, at, _fx_color(id, effect, kind), 3.0, 0.7)


func _fx_color(id: String, effect: String, kind: String) -> Color:
	match effect:
		"freeze", "slow": return Color(0.6, 0.9, 1.0)
		"burn": return Style.LAVA
		"shield": return Color(1.0, 0.85, 0.4)
		"rage": return Color(1.0, 0.3, 0.2)
		"stun": return Color(1.0, 0.95, 0.5)
	if kind == "area_heal":
		return Color(0.45, 1.0, 0.55)
	if id == "meteor":
		return Style.LAVA
	return Color(1.0, 0.85, 0.6)


func _float_text(pos: Vector3, text: String, color: Color, scale_k: float = 1.0) -> void:
	var l := Label3D.new()
	l.text_direction = TextServer.DIRECTION_RTL
	l.text = text
	l.font = PERCENT_FONT
	l.font_size = int(64 * scale_k)
	l.pixel_size = 0.006
	l.modulate = color
	l.outline_size = 14
	l.outline_modulate = Color(0.05, 0.02, 0.02)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(randf_range(-0.2, 0.2), 1.5, 0)
	_fx_root.add_child(l)
	var tw := l.create_tween().set_parallel(true)
	tw.tween_property(l, "position", l.position + Vector3(0, 0.7, 0), 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)


# ------------------------------------------------------------------ fog

func _build_fog() -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var q := BoxMesh.new()
	q.size = Vector3(1.0, 1.6, 1.0)
	mm.mesh = q
	mm.instance_count = _w * _h
	for i in _w * _h:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, TerrainView.cell_xz(i % _w, i / _w, _w, _h) + Vector3(0, 0.7, 0)))
		mm.set_instance_color(i, Color(0, 0, 0, 0))
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	_fog = MultiMeshInstance3D.new()
	_fog.multimesh = mm
	_fog.material_override = mat
	_fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_fog)
	_update_fog()


func _update_fog() -> void:
	var mm := _fog.multimesh
	var explored: PackedByteArray = battle.explored[viewer]
	for i in _w * _h:
		var p := Vector2(i % _w, i / _w)
		var a := 0.0
		if not battle.is_visible(viewer, p):
			a = 0.5 if explored[i] == 1 else 0.9
		mm.set_instance_color(i, Color(0.03, 0.03, 0.06, a))


# ------------------------------------------------------------------ game mode goals

var _crowns: Array = []      ## Node3D per battle.crowns entry
var _runes: Array = []       ## Node3D per battle.runes entry
var _thrones: Array = []     ## [Node3D, progress ring] per kingdom


func _objectives() -> void:
	_crowns.clear()
	_runes.clear()
	_thrones.clear()
	match battle.mode:
		"crown":
			for cr in battle.crowns:
				var n := _crown_model(Style.team(cr["team"])["ui"])
				add_child(n)
				_crowns.append(n)
				_throne_model(cr["team"], false)
		"throne":
			for team in 2:
				_thrones.append(_throne_model(team, true))
		"runes":
			for r in battle.runes:
				var n := Node3D.new()
				var stone := _part(n, _cyl_mesh(0.0, 0.22, 0.55), Style.glow(Color(0.75, 0.45, 1.0), 2.6), Vector3(0, 0.0, 0))
				_part(n, _cyl_mesh(0.22, 0.0, 0.3), Style.glow(Color(0.75, 0.45, 1.0), 2.6), Vector3(0, -0.42, 0))
				stone.rotation_degrees.x = 180
				var ring := MeshInstance3D.new()
				var t := TorusMesh.new()
				t.inner_radius = 0.42
				t.outer_radius = 0.5
				ring.mesh = t
				ring.material_override = Style.glow(Color(0.8, 0.5, 1.0), 1.2)
				ring.position.y = -0.62
				n.add_child(ring)
				add_child(n)
				_runes.append(n)


## A golden crown with jewels (it floats and turns slowly).
func _crown_model(jewel: Color) -> Node3D:
	var n := Node3D.new()
	var gold := Style.metal(Color(1.0, 0.78, 0.25))
	_part(n, _cyl_mesh(0.3, 0.3, 0.16), gold, Vector3.ZERO)
	for i in 5:
		var a := TAU * i / 5.0
		_part(n, _cyl_mesh(0.0, 0.07, 0.22), gold, Vector3(cos(a) * 0.27, 0.18, sin(a) * 0.27))
		_part(n, _cyl_mesh(0.05, 0.05, 0.05), Style.glow(jewel, 2.0), Vector3(cos(a) * 0.3, 0.02, sin(a) * 0.3))
	n.scale = Vector3.ONE * 1.3
	return n


## The king's throne at the back of the palace (a big golden chair).
func _throne_model(team: int, with_ring: bool) -> MeshInstance3D:
	var root := Node3D.new()
	root.position = to_world(Vector2(battle.map["palaces"][team]["seat"]))
	root.rotation_degrees.y = 0.0 if team == 0 else 180.0
	add_child(root)
	var gold := Style.metal(Color(1.0, 0.78, 0.25))
	var cloth := Style.cloth(Style.team(team)["ui"].darkened(0.2))
	_part(root, _box_mesh(Vector3(0.8, 0.35, 0.7)), gold, Vector3(0, 0.18, 0))
	_part(root, _box_mesh(Vector3(0.66, 0.1, 0.58)), cloth, Vector3(0, 0.4, 0.02))
	_part(root, _box_mesh(Vector3(0.8, 1.1, 0.14)), gold, Vector3(0, 0.75, -0.3))
	_part(root, _box_mesh(Vector3(0.6, 0.85, 0.05)), cloth, Vector3(0, 0.75, -0.22))
	for x in [-0.42, 0.42]:
		_part(root, _box_mesh(Vector3(0.1, 0.3, 0.6)), gold, Vector3(x, 0.5, 0))
		_part(root, _cyl_mesh(0.0, 0.08, 0.2), gold, Vector3(x * 0.9, 1.4, -0.3))
	_part(root, _cyl_mesh(0.0, 0.1, 0.28), gold, Vector3(0, 1.45, -0.3))
	if not with_ring:
		return null
	var ring := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.62
	t.outer_radius = 0.72
	t.rings = 48
	ring.mesh = t
	ring.material_override = Style.glow(Style.team(1 - team)["ui"], 1.4)
	ring.position.y = 0.05
	root.add_child(ring)
	return ring


func _update_objectives(delta: float) -> void:
	var spin := Time.get_ticks_msec() / 1000.0
	for i in _crowns.size():
		var cr: Dictionary = battle.crowns[i]
		var n: Node3D = _crowns[i]
		var carried: bool = cr["carrier"] >= 0
		var at_home: bool = Vector2(cr["pos"]) == Vector2(cr["home"])
		var goal := to_world(cr["pos"]) + Vector3(0, (2.1 if carried else (1.7 if at_home else 0.7)) + 0.12 * sin(spin * 2.0), 0)
		n.position = n.position.lerp(goal, minf(1.0, delta * 12.0)) if n.position != Vector3.ZERO else goal
		n.rotation.y = spin * 1.2
	for i in _runes.size():
		var r: Dictionary = battle.runes[i]
		var n: Node3D = _runes[i]
		n.visible = battle.time >= float(r["back_at"]) or r["carrier"] >= 0
		var carried: bool = r["carrier"] >= 0
		var goal := to_world(r["pos"]) + Vector3(0, (2.0 if carried else 0.85) + 0.1 * sin(spin * 2.5 + i), 0)
		n.position = n.position.lerp(goal, minf(1.0, delta * 12.0)) if n.position != Vector3.ZERO else goal
		n.rotation.y = spin * 2.0
	for team in _thrones.size():
		var ring: MeshInstance3D = _thrones[team]
		if ring == null:
			continue
		# the ring fills up as the enemy sits on this throne
		var k: float = battle.throne_time[1 - team] / Battle.THRONE_TIME
		ring.visible = k > 0.0
		ring.scale = Vector3.ONE * (0.6 + 0.6 * k)


# ------------------------------------------------------------------ spell shows

## Each of the four spell cards gets its own little show: the bomb or potion
## flies in from the caster's palace, lands, and then:
##   ice bomb    - a frost disc spreads, ice crystals shoot out of the ground, snow
##   fire bomb   - a fireball blast, flames, smoke rising and a burnt mark left behind
##   heal potion - the bottle shatters, a green dome of light, rising hearts
##   shield wall - golden shields slam down with dust and a ring of light
func _spell_show(id: String, pos: Vector2, radius: float, team: int) -> void:
	var at := to_world(pos)
	if id == "shield_wall":
		_shield_slam(at, team)
		return
	var from := to_world(Vector2(battle.map["palaces"][team]["gate"])) + Vector3(0, 1.5, 0)
	var thing := Node3D.new()
	_fx_root.add_child(thing)
	match id:
		"ice_bomb":
			_part(thing, _sphere(0.28), Style.glow(Color(0.6, 0.9, 1.0), 1.8), Vector3.ZERO)
			for i in 6:
				var sp := _part(thing, _cyl_mesh(0.0, 0.07, 0.3), Style.glow(Color.WHITE, 1.2), Vector3.ZERO)
				sp.rotation_degrees = Vector3(90, i * 60, 0)
				sp.position = Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(i * 60)) * 0.3
		"fire_bomb":
			_part(thing, _sphere(0.3), Style.toon(Color(0.12, 0.1, 0.1), 0.3, 0.4), Vector3.ZERO)
			_part(thing, _cyl_mesh(0.05, 0.05, 0.25), Style.matte(Color(0.55, 0.4, 0.25)), Vector3(0.12, 0.3, 0)).rotation_degrees.z = -30
			_part(thing, _sphere(0.08), Style.glow(Color(1.0, 0.7, 0.2), 4.0), Vector3(0.2, 0.44, 0))
		"heal_potion":
			_part(thing, _sphere(0.24), Style.glow(Color(1.0, 0.3, 0.4), 1.2), Vector3(0, -0.05, 0))
			_part(thing, _cyl_mesh(0.07, 0.09, 0.22), Style.toon(Color(0.85, 0.9, 1.0), 0.0, 0.2), Vector3(0, 0.25, 0))
			_part(thing, _cyl_mesh(0.08, 0.08, 0.08), Style.matte(Color(0.55, 0.35, 0.2)), Vector3(0, 0.38, 0))
	thing.position = from
	var top := from.lerp(at, 0.5) + Vector3(0, 4.0, 0)
	var tw := thing.create_tween()
	var fly := 0.45
	tw.tween_method(func(t: float):
		thing.position = from.lerp(top, t).lerp(top.lerp(at + Vector3(0, 0.3, 0), t), t)
		thing.rotation.x = t * 9.0, 0.0, 1.0, fly)
	tw.tween_callback(thing.queue_free)
	tw.tween_callback(_spell_land.bind(id, at, radius))


func _spell_land(id: String, at: Vector3, radius: float) -> void:
	match id:
		"ice_bomb":
			_ice_burst(at, radius)
		"fire_bomb":
			_fire_burst(at, radius)
		"heal_potion":
			_heal_burst(at, radius)


func _sphere(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


## A flat glowing disc that grows and fades on the ground.
func _disc(at: Vector3, color: Color, radius: float, grow: float, life: float) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _cyl_mesh(1.0, 1.0, 0.02)
	var mat := Style.overlay(color)
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = mat
	mi.position = at + Vector3(0, 0.09, 0)
	mi.scale = Vector3(radius * 0.2, 1, radius * 0.2)
	_fx_root.add_child(mi)
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3(radius, 1, radius), grow).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(mat, "albedo_color:a", 0.0, life).set_delay(grow)
	tw.chain().tween_callback(mi.queue_free)


func _ice_burst(at: Vector3, radius: float) -> void:
	_disc(at, Color(0.55, 0.85, 1.0, 0.7), radius, 0.25, 1.4)
	Effects.shockwave(_fx_root, at + Vector3(0, 0.05, 0), Color(0.8, 0.95, 1.0), radius)
	var ice := Style.glow(Color(0.7, 0.92, 1.0), 1.3)
	for i in 14:
		var a := TAU * i / 14.0 + randf() * 0.3
		var d := randf_range(0.35, radius * 0.95)
		var shard := _part(_fx_root, _cyl_mesh(0.0, randf_range(0.1, 0.18), randf_range(0.5, 1.1)), ice,
			at + Vector3(cos(a) * d, 0.0, sin(a) * d))
		shard.rotation = Vector3(randf_range(-0.4, 0.4), randf() * TAU, randf_range(-0.4, 0.4))
		shard.scale = Vector3(1, 0.01, 1)
		var tw := shard.create_tween()
		tw.tween_property(shard, "scale", Vector3.ONE, 0.18).set_delay(i * 0.015).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(1.2)
		tw.tween_property(shard, "scale", Vector3(0.01, 0.01, 0.01), 0.35)
		tw.tween_callback(shard.queue_free)
	Effects.storm(_fx_root, at + Vector3(0, 3.0, 0), Color(1, 1, 1), radius, 90)
	if camera_rig:
		camera_rig.shake(0.1, 0.3)


func _fire_burst(at: Vector3, radius: float) -> void:
	if camera_rig:
		camera_rig.shake(0.3, 0.5)
	# the fireball
	var ball := _part(_fx_root, _sphere(1.0), Style.glow(Color(1.0, 0.55, 0.12), 4.0), at + Vector3(0, 0.4, 0))
	ball.scale = Vector3.ONE * 0.2
	var tw := ball.create_tween()
	tw.tween_property(ball, "scale", Vector3.ONE * radius * 0.9, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(ball, "scale", Vector3.ONE * 0.01, 0.35).set_ease(Tween.EASE_IN)
	tw.tween_callback(ball.queue_free)
	var core := _part(_fx_root, _sphere(0.6), Style.glow(Color(1.0, 0.95, 0.6), 6.0), at + Vector3(0, 0.4, 0))
	var tc := core.create_tween()
	tc.tween_property(core, "scale", Vector3.ONE * 0.01, 0.3)
	tc.tween_callback(core.queue_free)
	Effects.shockwave(_fx_root, at + Vector3(0, 0.05, 0), Style.LAVA, radius)
	Effects.burst(_fx_root, at + Vector3(0, 0.4, 0), Color(1.0, 0.6, 0.15), 60, 6.0, 0.09)
	# smoke puffs rising
	for i in 7:
		var a := TAU * i / 7.0
		var puff := _part(_fx_root, _sphere(0.35), Style.overlay(Color(0.18, 0.16, 0.15, 0.75), false),
			at + Vector3(cos(a) * radius * 0.4, 0.5, sin(a) * radius * 0.4))
		var tp := puff.create_tween().set_parallel(true)
		tp.tween_property(puff, "position:y", 2.6 + randf(), 1.6).set_ease(Tween.EASE_OUT)
		tp.tween_property(puff, "scale", Vector3.ONE * 2.2, 1.6)
		tp.tween_property(puff.material_override, "albedo_color:a", 0.0, 1.6)
		tp.chain().tween_callback(puff.queue_free)
	# little flames dancing for a while
	for i in 8:
		var a2 := randf() * TAU
		var d := randf_range(0.2, radius * 0.8)
		var fl := _part(_fx_root, _cyl_mesh(0.0, 0.14, 0.45), Style.glow(Color(1.0, 0.5, 0.1), 3.0), at + Vector3(cos(a2) * d, 0.22, sin(a2) * d))
		var tf := fl.create_tween().set_loops(4)
		tf.tween_property(fl, "scale", Vector3(1.0, 1.6, 1.0), 0.18)
		tf.tween_property(fl, "scale", Vector3(0.8, 0.7, 0.8), 0.18)
		get_tree().create_timer(1.6).timeout.connect(func(): if is_instance_valid(fl): fl.queue_free())
	# the burnt mark stays a few seconds
	var mark := _part(_fx_root, _cyl_mesh(1.0, 1.0, 0.01), Style.overlay(Color(0.08, 0.06, 0.05, 0.7), false), at + Vector3(0, 0.08, 0))
	mark.scale = Vector3(radius * 0.8, 1, radius * 0.8)
	var tm := mark.create_tween()
	tm.tween_interval(3.0)
	tm.tween_property(mark.material_override, "albedo_color:a", 0.0, 1.5)
	tm.tween_callback(mark.queue_free)


func _heal_burst(at: Vector3, radius: float) -> void:
	Effects.burst(_fx_root, at + Vector3(0, 0.3, 0), Color(0.85, 0.95, 1.0), 24, 3.0, 0.05)  # glass
	_disc(at, Color(0.4, 1.0, 0.5, 0.6), radius, 0.3, 1.2)
	# a dome of green light
	var dome := _part(_fx_root, _sphere(1.0), Style.overlay(Color(0.45, 1.0, 0.55, 0.35)), at)
	dome.material_override.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	dome.scale = Vector3(0.1, 0.05, 0.1)
	var td := dome.create_tween()
	td.tween_property(dome, "scale", Vector3(radius, radius * 0.7, radius), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	td.tween_property(dome.material_override, "albedo_color:a", 0.0, 0.9)
	td.tween_callback(dome.queue_free)
	Effects.pillar(_fx_root, at, Color(0.45, 1.0, 0.55), 4.0, 0.9)
	# hearts and pluses float up
	for i in 9:
		var a := randf() * TAU
		var d := randf_range(0.0, radius * 0.8)
		var l := Label3D.new()
		l.text = "♥" if i % 2 == 0 else "✚"
		l.font = PERCENT_FONT
		l.font_size = 64
		l.outline_size = 10
		l.modulate = Color(1.0, 0.45, 0.55) if i % 2 == 0 else Color(0.5, 1.0, 0.55)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.pixel_size = 0.006
		l.position = at + Vector3(cos(a) * d, 0.4, sin(a) * d)
		_fx_root.add_child(l)
		var tl := l.create_tween().set_parallel(true)
		tl.tween_property(l, "position:y", l.position.y + 2.2, 1.3).set_delay(i * 0.06).set_ease(Tween.EASE_OUT)
		tl.tween_property(l, "modulate:a", 0.0, 0.6).set_delay(0.7 + i * 0.06)
		tl.chain().tween_callback(l.queue_free)


func _shield_slam(at: Vector3, team: int) -> void:
	var gold := Color(1.0, 0.82, 0.3)
	# three golden shields fall from the sky and slam into the ground
	for i in 3:
		var sh := Node3D.new()
		_fx_root.add_child(sh)
		_part(sh, _box_mesh(Vector3(0.36, 0.5, 0.06)), Style.metal(gold), Vector3.ZERO)
		_part(sh, _box_mesh(Vector3(0.24, 0.32, 0.07)), Style.cloth(Style.team(team)["ui"]), Vector3(0, 0.02, 0.01))
		var x := (i - 1) * 0.36
		sh.position = at + Vector3(x, 3.5 + i * 0.4, 0)
		var ts := sh.create_tween()
		ts.tween_property(sh, "position:y", at.y + 0.9, 0.22).set_delay(i * 0.07).set_ease(Tween.EASE_IN)
		ts.tween_callback(func():
			Effects.burst(_fx_root, at + Vector3(x, 0.2, 0), Color(0.7, 0.6, 0.45), 14, 2.5, 0.07)
			if camera_rig and i == 1:
				camera_rig.shake(0.12, 0.25))
		ts.tween_interval(0.5)
		ts.tween_property(sh, "scale", Vector3(0.01, 0.01, 0.01), 0.25)
		ts.tween_callback(sh.queue_free)
	Effects.ring(_fx_root, at, gold, 3.0, 0.6)
	_disc(at, Color(1.0, 0.85, 0.35, 0.5), 1.2, 0.25, 0.8)
