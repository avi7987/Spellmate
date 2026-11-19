class_name PieceView
extends Node3D
## One character on the board.
##
## Hierarchy:  PieceView (on the square, turns to face the camera)
##               ├─ Base      (flat team-coloured disc on the board)
##               └─ Lean      (tilted back so the top-down camera sees the face)
##                    └─ Model (+ shield / ice effects)
##
## The camera looks straight down (orthographic). Upright characters would only
## show the tops of their heads, so each character leans back by LEAN_DEGREES.

const LEAN_DEGREES := 0.0
## Feet sit a bit below the square centre so the leaning figure looks centred.
const FOOT_OFFSET := 0.0

var piece_id: int = -1
## The square this character currently stands on (kept up to date by BoardView).
var square: int = -1
var kind: int = Chess.Kind.NONE
var color: int = Chess.WHITE

var _lean: Node3D
var _hop: Node3D
var _model: Node3D
var _player: AnimationPlayer
var _anims: Dictionary = {}
var _dying := false
var _shield_fx: MeshInstance3D
var _ice_fx: MeshInstance3D
var _base: MeshInstance3D
var _time := randf() * 10.0


func setup(p: Piece) -> void:
	piece_id = p.id
	color = p.color
	_base = MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.36
	disc.bottom_radius = 0.4
	disc.height = 0.05
	_base.mesh = disc
	_base.material_override = Style.metal(Style.team(color)["metal"])
	_base.position = Vector3(0, 0.025, 0)
	add_child(_base)
	var inner := MeshInstance3D.new()
	var disc2 := CylinderMesh.new()
	disc2.top_radius = 0.3
	disc2.bottom_radius = 0.3
	disc2.height = 0.055
	inner.mesh = disc2
	inner.material_override = Style.cloth(Style.team(color)["cloth"])
	inner.position = Vector3(0, 0.03, 0)
	add_child(inner)

	_lean = Node3D.new()
	_lean.position = Vector3(0, 0.05, FOOT_OFFSET)
	_lean.rotation_degrees = Vector3(-LEAN_DEGREES, 0, 0)
	add_child(_lean)
	_hop = Node3D.new()
	_lean.add_child(_hop)
	_build_model(p.kind)


func _build_model(new_kind: int) -> void:
	if _model != null:
		_model.queue_free()
	kind = new_kind
	_model = PieceModelFactory.build(kind, color)
	_anims = _model.get_meta("anims", {})
	_player = _model.get_meta("player", null)
	if _player == null:
		_model.scale = Vector3.ONE * 0.85  # placeholder shapes
	_hop.add_child(_model)
	_play_idle(true)


## True when this character has real animations (not a placeholder).
func is_animated() -> bool:
	return _player != null


func _play_idle(random_start: bool = false) -> void:
	if _player == null or not _anims.has("idle"):
		return
	var anim: Animation = _player.get_animation(_anims["idle"])
	if anim == null:
		return
	anim.loop_mode = Animation.LOOP_LINEAR
	_player.play(_anims["idle"], 0.25)
	if random_start:
		_player.seek(randf() * anim.length, true)


## Plays a one-shot animation by role ("attack", "cast", "hit", ...).
## Waits `wait_fraction` of it, then returns (the rest keeps playing).
func play_action(role: String, wait_fraction: float = 1.0, back_to_idle: bool = true) -> void:
	if _player == null or not _anims.has(role) or not _player.has_animation(_anims[role]):
		await bounce()
		return
	var name: String = _anims[role]
	var anim := _player.get_animation(name)
	anim.loop_mode = Animation.LOOP_NONE
	_player.play(name, 0.15)
	await get_tree().create_timer(anim.length * wait_fraction).timeout
	if back_to_idle and wait_fraction >= 1.0:
		_play_idle()
	elif back_to_idle:
		# Return to idle when the animation really ends, without blocking.
		get_tree().create_timer(anim.length * (1.0 - wait_fraction)).timeout.connect(
			func(): if is_instance_valid(self) and _player.current_animation == name: _play_idle())


func set_kind(new_kind: int) -> void:
	if new_kind != kind:
		_build_model(new_kind)


## The character's screen-space "body" (feet and head points) for click picking.
func screen_segment(cam: Camera3D) -> Array:
	var feet := _lean.to_global(Vector3(0, 0.1, 0))
	var head := _lean.to_global(Vector3(0, 1.05, 0))
	return [cam.unproject_position(feet), cam.unproject_position(head)]


## Health bar over the head (shown once the unit is hurt).
func set_health(hp: int, max_hp: int) -> void:
	if _bar == null:
		_bar = HealthBar3D.new()
		_bar.bar_color = Style.team(color)["ui"]
		_bar.position = Vector3(0, 1.45, 0)
		add_child(_bar)
	_bar.set_health(hp, max_hp)


## A unit that already used its turn is shown a little darker.
func set_spent(spent: bool) -> void:
	if spent == _spent:
		return
	_spent = spent
	if _base != null:
		_base.material_override = Style.metal(Style.team(color)["metal"].darkened(0.6 if spent else 0.0))


## Walks along a list of world points (one square at a time).
func walk_path(points: Array) -> void:
	if points.is_empty():
		return
	if _player != null and _anims.has("move"):
		var walk: Animation = _player.get_animation(_anims["move"])
		walk.loop_mode = Animation.LOOP_LINEAR
		_player.play(_anims["move"], 0.1)
	var flying := kind == Chess.Kind.DRAGON
	for pt in points:
		var target: Vector3 = pt
		# Face the way we walk.
		var dir: Vector3 = target - position
		if dir.length() > 0.01 and _model != null:
			_model.rotation.y = atan2(dir.x, dir.z)
		var tw := create_tween()
		tw.tween_property(self, "position", target, 0.16)
		if flying:
			tw.parallel().tween_property(_hop, "position:y", 0.6, 0.16)
		await tw.finished
	if _model != null:
		var face := create_tween()
		face.tween_property(_model, "rotation:y", 0.0, 0.2)
	_hop.position.y = 0.0
	_play_idle()


## Turn so the character leans toward the camera (yaw 0 = White at the bottom).
func set_facing(yaw_degrees: float) -> void:
	rotation_degrees.y = yaw_degrees


func set_status(shielded: bool, frozen: bool) -> void:
	if shielded and _shield_fx == null:
		_shield_fx = MeshInstance3D.new()
		var s := SphereMesh.new()
		s.radius = 0.55
		s.height = 1.1
		_shield_fx.mesh = s
		_shield_fx.material_override = Style.overlay(Style.SHIELD)
		_shield_fx.position = Vector3(0, 0.5, 0)
		_hop.add_child(_shield_fx)
		_shield_fx.scale = Vector3.ZERO
		create_tween().tween_property(_shield_fx, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	elif not shielded and _shield_fx != null:
		_shield_fx.queue_free()
		_shield_fx = null
	if frozen and _ice_fx == null:
		_ice_fx = MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.32
		c.bottom_radius = 0.4
		c.height = 1.15
		c.radial_segments = 6
		_ice_fx.mesh = c
		_ice_fx.material_override = Style.overlay(Style.ICE, false)
		_ice_fx.position = Vector3(0, 0.55, 0)
		_hop.add_child(_ice_fx)
	elif not frozen and _ice_fx != null:
		_ice_fx.queue_free()
		_ice_fx = null


var _orbit: Node3D
var _bar: HealthBar3D
var _spent := false


func _process(delta: float) -> void:
	if _orbit == null and _model != null:
		_orbit = _model.find_child("Orbit", true, false)
	if _orbit != null:
		_orbit.rotate_y(delta * 1.4)
	# Gentle idle "breathing" so the characters feel alive (not when frozen).
	_time += delta
	if _player != null:
		if _dying:
			return
		if _ice_fx != null and _player.is_playing():
			_player.pause()
		elif _ice_fx == null and not _player.is_playing():
			_play_idle()
		return
	if _ice_fx == null and _model != null:
		var s := 1.0 + sin(_time * 2.2) * 0.015
		_model.scale = Vector3(0.85 * (2.0 - s), 0.85 * s, 0.85)


## Moves to a new spot with a little jump. `high` = bigger jump (dragon).
func move_to(target: Vector3, duration: float = 0.32, high: bool = false) -> void:
	if _player != null and _anims.has("move"):
		var walk: Animation = _player.get_animation(_anims["move"])
		walk.loop_mode = Animation.LOOP_LINEAR
		_player.play(_anims["move"], 0.1)
		duration = maxf(duration, 0.18 * position.distance_to(target) + 0.2)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "position", target, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var h := 0.6 if high else 0.25
	tw.tween_method(func(t: float): _hop.position.y = sin(t * PI) * h, 0.0, 1.0, duration)
	await tw.finished
	_play_idle()


## Plays the death animation and stays down (used for the checkmated king).
func fall() -> void:
	_dying = true
	if _player != null:
		await play_action("hit", 0.5, false)
		await play_action("death", 1.0, false)
	else:
		var tw := create_tween()
		tw.tween_property(_lean, "rotation_degrees:x", -90.0, 0.5).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		await tw.finished


## Death animation (if any), then a cute "poof" - shrinks and spins away.
func defeat() -> void:
	_dying = true
	if _player != null:
		await play_action("hit", 0.6, false)
		await play_action("death", 0.85, false)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_lean, "scale", Vector3(1.3, 0.2, 1.3), 0.15)
	tw.chain().tween_property(self, "scale", Vector3.ZERO, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(self, "rotation_degrees:y", rotation_degrees.y + 360.0, 0.25)
	await tw.finished


func pop_in() -> void:
	scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	await tw.finished


func bounce() -> void:
	var tw := create_tween()
	tw.tween_property(_hop, "position:y", 0.25, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(_hop, "position:y", 0.0, 0.18).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	await tw.finished
