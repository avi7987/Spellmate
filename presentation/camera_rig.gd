class_name CameraRig
extends Node3D
## The gameplay camera: an angled view (like Clash Royale) that can scroll over
## the big world and zoom.
##   - Move: WASD / arrow keys, or drag with the right (or middle) mouse button
##   - Zoom: mouse wheel
##   - look_at_square() glides to a spot (start of turn, selected unit)
##   - focus() swoops in for power cinematics, orbit_menu() circles behind the menu

const PITCH := -55.0
const FOV := 42.0
const MIN_DIST := 9.0
const MAX_DIST := 30.0
const PAN_SPEED := 14.0

var camera: Camera3D
var view_yaw: float = 0.0
## Point on the ground the camera looks at, and how far away it is.
var target := Vector3.ZERO
var distance := 22.0
var _shake_left := 0.0
var _shake_strength := 0.0
var _orbiting := false
var _orbit_angle := 0.0
var _dragging := false
var _cinematic := false
var _limit := Vector2(Chess.W / 2.0, Chess.H / 2.0)


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = FOV
	camera.near = 0.1
	camera.far = 300.0
	add_child(camera)
	camera.make_current()
	_apply()


func _transform_for(look: Vector3, dist: float, yaw_deg: float) -> Transform3D:
	var dir := Vector3(0, -sin(deg_to_rad(PITCH)), cos(deg_to_rad(PITCH))).rotated(Vector3.UP, deg_to_rad(yaw_deg))
	var pos := look + dir * dist
	return Transform3D(Basis.looking_at(look - pos, Vector3.UP), pos)


func _apply() -> void:
	target.x = clampf(target.x, -_limit.x, _limit.x)
	target.z = clampf(target.z, -_limit.y, _limit.y + 2.0)
	camera.transform = _transform_for(target, distance, 0.0)


## Glides to look at a point on the ground.
func look_at_point(p: Vector3, animate: bool = true) -> void:
	_orbiting = false
	if not animate:
		target = Vector3(p.x, 0, p.z)
		_apply()
		return
	var tw := create_tween()
	tw.tween_method(func(v: Vector3): target = v; _apply(), target, Vector3(p.x, 0, p.z), 0.5) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Back to the normal game view after a cinematic.
func reset_view(animate: bool = true) -> void:
	_orbiting = false
	_cinematic = false
	if animate:
		var tw := create_tween()
		tw.tween_property(camera, "transform", _transform_for(target, distance, 0.0), 0.5).set_trans(Tween.TRANS_CUBIC)
		await tw.finished
	else:
		_apply()


## Swoops in close to a point (for power cinematics).
func focus(p: Vector3, dist: float = 7.0, duration: float = 0.5) -> void:
	_orbiting = false
	_cinematic = true
	var tw := create_tween()
	tw.tween_property(camera, "transform", _transform_for(p, dist, 12.0), duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	await tw.finished


## Slowly circles over the world (behind the main menu).
func orbit_menu(on: bool) -> void:
	_orbiting = on
	if not on:
		reset_view(true)


func make_current() -> void:
	camera.make_current()


func set_view_yaw(yaw: float, _animate: bool = true) -> void:
	view_yaw = yaw


func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_left = duration


func _unhandled_input(event: InputEvent) -> void:
	if _orbiting or _cinematic:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			distance = clampf(distance - 1.5, MIN_DIST, MAX_DIST)
			_apply()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			distance = clampf(distance + 1.5, MIN_DIST, MAX_DIST)
			_apply()
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		var k := distance / 600.0
		target -= Vector3(event.relative.x, 0, event.relative.y) * k
		_apply()
	elif event is InputEventPanGesture:
		target += Vector3(event.delta.x, 0, event.delta.y) * 0.5
		_apply()
	elif event is InputEventMagnifyGesture:
		distance = clampf(distance / event.factor, MIN_DIST, MAX_DIST)
		_apply()


func _process(delta: float) -> void:
	if _orbiting:
		_orbit_angle += delta * 5.0
		camera.transform = _transform_for(Vector3.ZERO, 34.0, _orbit_angle)
	elif not _cinematic:
		var dir := Vector3.ZERO
		if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
		if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
		if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.z -= 1
		if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.z += 1
		if dir != Vector3.ZERO:
			target += dir.normalized() * PAN_SPEED * delta * (distance / 16.0)
			_apply()
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
