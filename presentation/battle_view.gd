class_name BattleView
extends Node3D
## Draws a real-time battle: the map, palaces (gate + towers), heroes,
## shots, spells, numbers, the fog of war, selection rings and order markers.
## It only READS the Battle; orders go through game/battle_main.gd.

const ENV_DIR := "res://assets/environment/kaykit/"
const PERCENT_FONT := preload("res://assets/fonts/SuezOne.ttf")

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
	ground.material_override = Style.matte(Style.GRASS.darkened(0.25))
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
	_terrain_view.build(b.map["terrain"], _w, _h)
	_scenery()
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
		if v is UnitView:
			v.visible = seen
			v.follow(u, to_world(u.pos), now, delta)
		elif v.has_meta("bar"):
			v.get_meta("bar").set_health(int(u.hp), int(u.max_hp))
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
				_area_fx(e["card"], e["pos"], e["radius"], e["pos"])
			"breach":
				_terrain_view.build(battle.map["terrain"], _w, _h)
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
			var ab: Dictionary = BattleData.hero(h).get("ability", {})
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
