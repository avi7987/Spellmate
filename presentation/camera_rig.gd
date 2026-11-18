class_name CameraRig
extends Node3D
## The gameplay camera: an angled view of the battlefield (like Clash Royale),
## from behind the Sun kingdom's side. Characters stand upright and face it.
##
## Extra moves: focus() zooms toward a spot for power cinematics,
## orbit_menu() slowly circles the field behind the main menu,
## shake() for impacts.

const PITCH := -56.0        ## degrees down from horizontal
const DISTANCE := 17.5      ## from the board centre
const FOV := 40.0
const LOOK_AT := Vector3(0, 0, 0.6)

var camera: Camera3D
var view_yaw: float = 0.0
var _shake_left := 0.0
var _shake_strength := 0.0
var _base_transform: Transform3D
var _orbiting := false
var _orbit_angle := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = FOV
	camera.near = 0.1
	camera.far = 200.0
	add_child(camera)
	_base_transform = _transform_for(LOOK_AT, DISTANCE, 0.0)
	camera.transform = _base_transform
	camera.make_current()


func _transform_for(target: Vector3, dist: float, yaw_deg: float) -> Transform3D:
	var dir := Vector3(0, -sin(deg_to_rad(PITCH)), cos(deg_to_rad(PITCH))).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	var pos := target + dir * dist
	return Transform3D(Basis.looking_at(target - pos, Vector3.UP), pos)


## Back to the normal game view.
func reset_view(animate: bool = true) -> void:
	_orbiting = false
	if animate:
		var tw := create_tween()
		tw.tween_property(camera, "transform", _base_transform, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		await tw.finished
	else:
		camera.transform = _base_transform


## Moves in close to a point (for power cinematics).
func focus(target: Vector3, dist: float = 7.0, duration: float = 0.5) -> void:
	_orbiting = false
	var tw := create_tween()
	tw.tween_property(camera, "transform", _transform_for(target, dist, 12.0), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Slowly circles the battlefield (behind the main menu).
func orbit_menu(on: bool) -> void:
	_orbiting = on
	if not on:
		reset_view(true)


func make_current() -> void:
	camera.make_current()


## Kept for older callers; the angled view never rotates with the turn.
func set_view_yaw(yaw: float, _animate: bool = true) -> void:
	view_yaw = yaw


func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_left = duration


func _process(delta: float) -> void:
	if _orbiting:
		_orbit_angle += delta * 6.0
		camera.transform = _transform_for(Vector3.ZERO, 19.0, _orbit_angle)
	if _shake_left > 0.0:
		_shake_left -= delta
		camera.h_offset = randf_range(-1, 1) * _shake_strength
		camera.v_offset = randf_range(-1, 1) * _shake_strength
		if _shake_left <= 0.0:
			camera.h_offset = 0.0
			camera.v_offset = 0.0


## The square under a screen position, or -1.
func square_at_screen(screen_pos: Vector2) -> int:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return -1
	var t := (0.1 - origin.y) / dir.y
	var hit := origin + dir * t
	return BoardView.world_to_square(hit)
