class_name CameraRig
extends Node3D
## The gameplay camera: orthographic, looking straight down (90°) at the board.
## No perspective, so all 64 squares stay perfectly aligned.
## `view_yaw` 0 = White at the bottom, 180 = Black at the bottom.

const HEIGHT := 30.0
const VIEW_SIZE := 10.4  ## world units visible vertically

var camera: Camera3D
var view_yaw: float = 0.0
var _shake_left := 0.0
var _shake_strength := 0.0


func _ready() -> void:
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_SIZE
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.1
	camera.far = 100.0
	camera.position = Vector3(0, HEIGHT, 0)
	camera.rotation_degrees = Vector3(-90, 0, 0)
	add_child(camera)
	camera.make_current()


func set_view_yaw(yaw: float, animate: bool = true) -> void:
	view_yaw = yaw
	if animate:
		var tw := create_tween()
		tw.tween_property(self, "rotation_degrees:y", yaw, 0.6).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	else:
		rotation_degrees.y = yaw


func shake(strength: float, duration: float) -> void:
	_shake_strength = strength
	_shake_left = duration


func _process(delta: float) -> void:
	if _shake_left > 0.0:
		_shake_left -= delta
		camera.position = Vector3(randf_range(-1, 1) * _shake_strength, HEIGHT, randf_range(-1, 1) * _shake_strength)
		if _shake_left <= 0.0:
			camera.position = Vector3(0, HEIGHT, 0)


## The square under a screen position, or -1.
func square_at_screen(screen_pos: Vector2) -> int:
	var origin := camera.project_ray_origin(screen_pos)
	var dir := camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return -1
	var t := (0.1 - origin.y) / dir.y
	var hit := origin + dir * t
	return BoardView.world_to_square(hit)
