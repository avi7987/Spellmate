class_name UnitView
extends Node3D
## One hero (or the king) in a real-time battle. Follows its BUnit smoothly,
## turns to where it walks or fights, plays walk / attack / hit / death
## animations, shows a health bar, a team ring, a selection ring and effects
## (frozen, shield, rage, burning, slowed).

## Characters are drawn a bit bigger than real size so they read well on the map.
const SIZE := 1.4

var unit_id := -1
var team := 0
var kind := ""
var flying := false
var dying := false

var _hop: Node3D
var _model: Node3D
var _player: AnimationPlayer
var _anims: Dictionary = {}
var _bar: HealthBar3D
var _ring: MeshInstance3D
var _select: MeshInstance3D
var _fx: Dictionary = {}          ## effect name -> Node3D
var _moving := false
var _action_until := 0.0
var _clock := 0.0
var _yaw := 0.0
var _base_scale := 1.0


func setup(u: BUnit) -> void:
	unit_id = u.id
	team = u.team
	kind = u.kind
	flying = u.flying
	_ring = _disc(0.34 if u.radius < 0.4 else 0.5, Style.team(team)["ui"], 0.55)
	_ring.position.y = 0.03
	add_child(_ring)
	_select = _disc(0.46 if u.radius < 0.4 else 0.66, Color(1, 1, 1, 0.9), 0.0, true)
	_select.position.y = 0.04
	_select.visible = false
	add_child(_select)
	_hop = Node3D.new()
	add_child(_hop)
	_model = PieceModelFactory.build_hero(kind, team)
	_anims = _model.get_meta("anims", {})
	_player = (_model.get_meta("player") if _model.has_meta("player") else null)
	_hop.add_child(_model)
	_model.scale *= SIZE
	_base_scale = _model.scale.x
	_yaw = 0.0 if team == 0 else PI
	_model.rotation.y = _yaw
	_play_loop("idle", true)
	_bar = HealthBar3D.new()
	_bar.bar_color = Style.team(team)["ui"]
	_bar.position = Vector3(0, 1.9 if u.radius < 0.4 else 2.8, 0)
	if flying:
		_bar.position.y += 1.0
	add_child(_bar)
	_bar.set_health(int(u.hp), int(u.max_hp))


func _disc(r: float, c: Color, inner: float, ring: bool = false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if ring:
		var t := TorusMesh.new()
		t.inner_radius = r * 0.86
		t.outer_radius = r
		t.rings = 32
		mi.mesh = t
		mi.scale = Vector3(1, 0.15, 1)
	else:
		var d := CylinderMesh.new()
		d.top_radius = r
		d.bottom_radius = r
		d.height = 0.02
		mi.mesh = d
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(c.r, c.g, c.b, inner if inner > 0.0 else c.a)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func set_selected(on: bool) -> void:
	_select.visible = on


## Called every frame with the unit's current state.
func follow(u: BUnit, world: Vector3, now: float, delta: float) -> void:
	_clock += delta
	var before := position
	position = position.lerp(world, minf(1.0, delta * 14.0)) if position.distance_to(world) < 3.0 else world
	var moved := (position - before).length() / maxf(delta, 0.001)
	var walking := moved > 0.25
	if walking:
		var dir := position - before
		_yaw = atan2(dir.x, dir.z)
	elif u.facing.length() > 0.1:
		_yaw = atan2(u.facing.x, -u.facing.y)
	_model.rotation.y = lerp_angle(_model.rotation.y, _yaw, minf(1.0, delta * 10.0))
	if flying:
		_hop.position.y = 1.0 + sin(_clock * 2.5) * 0.12
	var frozen := u.has_effect("freeze", now) or u.has_effect("stun", now)
	if _player != null:
		if frozen:
			_player.speed_scale = 0.0
		else:
			_player.speed_scale = 0.6 if u.has_effect("slow", now) else 1.0
			if _clock >= _action_until and walking != _moving:
				_moving = walking
				_play_loop("move" if walking else "idle")
	elif walking:
		_hop.position.y = absf(sin(_clock * 12.0)) * 0.08 + (1.0 if flying else 0.0)
	_bar.set_health(int(u.hp), int(u.max_hp))
	for e in ["freeze", "stun", "shield", "rage", "burn", "slow"]:
		_set_fx(e, u.has_effect(e, now))


func _play_loop(role: String, random_start: bool = false) -> void:
	if _player == null or not _anims.has(role) or not _player.has_animation(_anims[role]):
		return
	var a := _player.get_animation(_anims[role])
	a.loop_mode = Animation.LOOP_LINEAR
	_player.play(_anims[role], 0.15)
	if random_start:
		_player.seek(randf() * a.length, true)


## A one-shot animation ("attack", "cast", "hit"), then back to idle/walk.
func play_once(role: String) -> void:
	if dying:
		return
	if _player == null or not _anims.has(role) or not _player.has_animation(_anims[role]):
		var tw := create_tween()
		tw.tween_property(_hop, "scale", Vector3(1.15, 0.85, 1.15), 0.08)
		tw.tween_property(_hop, "scale", Vector3.ONE, 0.15)
		return
	if role == "hit" and _clock < _action_until:
		return   # do not cut an attack short for a small hit
	var a := _player.get_animation(_anims[role])
	a.loop_mode = Animation.LOOP_NONE
	_player.play(_anims[role], 0.08)
	_action_until = _clock + minf(a.length, 1.2)
	_moving = not _moving   # forces the loop to restart afterwards


func die() -> void:
	dying = true
	_bar.visible = false
	_ring.visible = false
	_select.visible = false
	for k in _fx:
		_fx[k].queue_free()
	_fx.clear()
	if _player != null and _anims.has("death") and _player.has_animation(_anims["death"]):
		_player.speed_scale = 1.0
		var a := _player.get_animation(_anims["death"])
		a.loop_mode = Animation.LOOP_NONE
		_player.play(_anims["death"], 0.1)
		await get_tree().create_timer(minf(a.length, 1.4)).timeout
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3(1.2, 0.05, 1.2), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tw.finished
	queue_free()


func pop_in() -> void:
	scale = Vector3(0.01, 0.01, 0.01)
	create_tween().tween_property(self, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## The character's screen-space body (feet and head points) for click picking.
func screen_segment(cam: Camera3D) -> Array:
	var feet := global_position + Vector3(0, 0.1 + _hop.position.y, 0)
	var head := global_position + Vector3(0, 1.1 * _base_scale / 0.5 + _hop.position.y, 0)
	return [cam.unproject_position(feet), cam.unproject_position(head)]


func _set_fx(name: String, on: bool) -> void:
	if on == _fx.has(name):
		return
	if not on:
		_fx[name].queue_free()
		_fx.erase(name)
		return
	var mi := MeshInstance3D.new()
	match name:
		"freeze":
			var c := CylinderMesh.new()
			c.top_radius = 0.34
			c.bottom_radius = 0.42
			c.height = 1.2
			c.radial_segments = 6
			mi.mesh = c
			mi.material_override = Style.overlay(Style.ICE, false)
			mi.position.y = 0.6
		"stun":
			var t := TorusMesh.new()
			t.inner_radius = 0.22
			t.outer_radius = 0.28
			mi.mesh = t
			mi.material_override = Style.glow(Color(1, 0.9, 0.3), 2.0)
			mi.position.y = 1.35
		"shield":
			var s := SphereMesh.new()
			s.radius = 0.6
			s.height = 1.2
			mi.mesh = s
			mi.material_override = Style.overlay(Style.SHIELD)
			mi.position.y = 0.55
		"rage":
			var t2 := TorusMesh.new()
			t2.inner_radius = 0.36
			t2.outer_radius = 0.44
			mi.mesh = t2
			mi.material_override = Style.glow(Color(1.0, 0.25, 0.15), 2.0)
			mi.position.y = 0.1
		"burn":
			var c2 := CylinderMesh.new()
			c2.top_radius = 0.0
			c2.bottom_radius = 0.25
			c2.height = 0.5
			mi.mesh = c2
			mi.material_override = Style.glow(Style.LAVA, 2.5)
			mi.position.y = 1.1
		"slow":
			var t3 := TorusMesh.new()
			t3.inner_radius = 0.3
			t3.outer_radius = 0.38
			mi.mesh = t3
			mi.material_override = Style.glow(Color(0.5, 0.85, 1.0), 1.6)
			mi.position.y = 0.15
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_hop.add_child(mi)
	_fx[name] = mi


func _process(delta: float) -> void:
	if _fx.has("stun"):
		_fx["stun"].rotate_y(delta * 5.0)
	if _fx.has("burn"):
		_fx["burn"].scale = Vector3.ONE * (0.8 + absf(sin(_clock * 9.0)) * 0.4)
