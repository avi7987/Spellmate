class_name HealthBar3D
extends Node3D
## A small health bar floating over a unit or structure on the map
## (always faces the camera).

var bar_color := Color(0.4, 0.9, 0.4)
var _bg: MeshInstance3D
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D
const WIDTH := 0.8


func _ready() -> void:
	_bg = _quad(Color(0.05, 0.04, 0.05, 0.85), Vector2(WIDTH + 0.06, 0.13), 0)
	_fill_mat = _material(bar_color, 1)
	_fill = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(WIDTH, 0.08)
	_fill.mesh = q
	_fill.material_override = _fill_mat
	add_child(_fill)


func _material(c: Color, priority: int) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.no_depth_test = true
	m.render_priority = 5 + priority
	return m


func _quad(c: Color, size: Vector2, priority: int) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = _material(c, priority)
	add_child(mi)
	return mi


func set_health(hp: int, max_hp: int) -> void:
	if _fill == null:
		await ready
	var f := clampf(float(hp) / maxf(1.0, float(max_hp)), 0.0, 1.0)
	# The fill shrinks toward the left edge of the bar.
	var q := _fill.mesh as QuadMesh
	q.size = Vector2(WIDTH * f, 0.08)
	q.center_offset = Vector3(-WIDTH * (1.0 - f) * 0.5, 0, 0)
	var c := bar_color if f > 0.35 else Color(1.0, 0.35, 0.25)
	_fill_mat.albedo_color = c
	visible = hp < max_hp or max_hp >= 30
