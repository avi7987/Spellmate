class_name Scenery
extends Node3D
## Decorations around the board: castles of both kingdoms, trees, rocks, tents
## and drifting clouds (KayKit Medieval Hexagon pack, CC0).
## Like the characters, props lean toward the top-down camera so we see their sides.

const DIR := "res://assets/environment/kaykit/"
const LEAN := 0.0

## [model, x, z, scale, yaw]  - x/z in board units (the board spans -4.6..4.6)
const PROPS := [
	# Kingdom of Light (bottom)
	["building_castle_blue", -6.6, 3.2, 1.25, 0.0],
	["building_tower_A_blue", 6.2, 3.9, 1.1, 30.0],
	["building_windmill_blue", 7.4, 1.6, 1.0, 0.0],
	["tent", -5.6, 1.2, 1.0, 20.0],
	["flag_blue", -5.3, 4.4, 1.2, 0.0],
	["flag_blue", 5.3, 4.4, 1.2, 0.0],
	["weaponrack", 5.6, 2.4, 1.0, -20.0],
	# Kingdom of Shadow (top)
	["building_castle_red", 6.6, -3.6, 1.25, 180.0],
	["building_tower_A_red", -6.2, -4.1, 1.1, 210.0],
	["building_home_A_red", -7.3, -1.8, 1.0, 160.0],
	["flag_red", -5.3, -4.4, 1.2, 0.0],
	["flag_red", 5.3, -4.4, 1.2, 0.0],
	["barrel", 5.5, -1.7, 1.0, 0.0],
	["crate_A_big", 5.8, -2.4, 1.0, 15.0],
	# Nature all around
	["trees_A_large", -7.2, 0.2, 1.2, 0.0],
	["trees_B_large", 7.3, -0.4, 1.2, 40.0],
	["trees_A_medium", -5.5, -2.6, 1.0, 80.0],
	["trees_B_medium", 6.0, 0.9, 1.0, 10.0],
	["tree_single_A", -8.3, 2.0, 1.0, 0.0],
	["tree_single_B", 8.4, -2.4, 1.0, 0.0],
	["tree_single_A", -0.8, -5.6, 0.9, 0.0],
	["tree_single_B", 2.6, 5.7, 0.9, 0.0],
	["hills_A_trees", -8.4, -3.4, 1.0, 0.0],
	["mountain_A_grass_trees", 8.6, 3.6, 1.0, 0.0],
	["rock_single_A", -5.4, 2.4, 1.0, 0.0],
	["rock_single_B", 5.4, -0.6, 1.0, 50.0],
	["rock_single_C", -2.6, 5.5, 1.0, 0.0],
	["rock_single_A", 1.4, -5.5, 0.9, 120.0],
]

var _items: Array = []


func _ready() -> void:
	# Positions were drawn for an 8x8 board; spread them around the bigger field.
	var spread := Vector2(Chess.W / 8.0 * 1.02, Chess.H / 8.0 * 1.02)
	for p in PROPS:
		_place(p[0], Vector3(p[1] * spread.x, -0.3, p[2] * spread.y), p[3] * 1.15, p[4])
	_add_clouds()


func _place(model: String, pos: Vector3, s: float, yaw: float) -> void:
	var path: String = DIR + model + ".gltf"
	if not ResourceLoader.exists(path):
		return
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	var lean := Node3D.new()
	lean.rotation_degrees.x = -LEAN
	root.add_child(lean)
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	inst.scale = Vector3.ONE * s
	inst.rotation_degrees.y = yaw
	lean.add_child(inst)
	_items.append(root)


func _add_clouds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 3:
		var path := DIR + ("cloud_big" if i % 2 == 0 else "cloud_small") + ".gltf"
		if not ResourceLoader.exists(path):
			return
		var c := (load(path) as PackedScene).instantiate() as Node3D
		c.position = Vector3(rng.randf_range(-12, 12), 6.0 + i * 0.3, rng.randf_range(-6, 6))
		c.scale = Vector3.ONE * rng.randf_range(0.55, 0.8)
		# Only the clouds' shadows are drawn, drifting over the board.
		for m in c.find_children("*", "GeometryInstance3D", true, false):
			m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
		add_child(c)
		_drift(c, rng.randf_range(0.15, 0.3))


func _drift(cloud: Node3D, speed: float) -> void:
	var tw := cloud.create_tween().set_loops()
	var start_x := cloud.position.x
	var t1 := (12.0 - start_x) / speed
	tw.tween_property(cloud, "position:x", 12.0, t1)
	tw.tween_callback(func(): cloud.position.x = -14.0)
	tw.tween_property(cloud, "position:x", start_x, (start_x + 14.0) / speed)


## Turn props to lean toward the camera when the board view flips.
func set_facing(yaw: float) -> void:
	for it in _items:
		var tw: Tween = it.create_tween()
		tw.tween_property(it, "rotation_degrees:y", yaw, 0.6).set_trans(Tween.TRANS_CUBIC)
