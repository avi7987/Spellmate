class_name TerrainView
extends Node3D
## Draws the world's squares from GameState.terrain: stone and grass tiles,
## forests with small trees, raised hills, the river with bridges, glowing
## crystal mines, palace floors and palace walls.
## Identical tiles are batched into MultiMeshes so a 30x30 world stays fast in
## the browser.

const TILE_HEIGHT := 0.2
const HILL_RAISE := 0.14
const WATER_DROP := 0.12
const WALL_HEIGHT := 0.9
const TREES := ["tree_single_A", "tree_single_B"]
const ENV_DIR := "res://assets/environment/kaykit/"
const WATER_SHADER := preload("res://presentation/shaders/water.gdshader")

var _batches: Dictionary = {}   # key -> { mesh, material, transforms }


## Height of the top of a square (where units stand).
static func top_of(terrain: int) -> float:
	match terrain:
		Chess.Terrain.HILL:
			return TILE_HEIGHT * 0.5 + HILL_RAISE
		Chess.Terrain.WATER:
			return TILE_HEIGHT * 0.5 - WATER_DROP
		Chess.Terrain.WALL:
			return TILE_HEIGHT * 0.5 + WALL_HEIGHT
	return TILE_HEIGHT * 0.5


func build(terrain: PackedInt32Array) -> void:
	for c in get_children():
		c.queue_free()
	_batches.clear()
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for s in Chess.N:
		var t: int = terrain[s]
		var pos := BoardView.square_xz(s)
		var shade := rng.randi() % 3   # three shades per tile type look hand-made
		match t:
			Chess.Terrain.WATER:
				_add("water", Vector3(1.0, 0.06, 1.0), water, pos + Vector3(0, -WATER_DROP + 0.04, 0))
			Chess.Terrain.BRIDGE:
				_add("water", Vector3(1.0, 0.06, 1.0), water, pos + Vector3(0, -WATER_DROP + 0.04, 0))
				for i in 5:
					_add("plank", Vector3(0.18, 0.06, 0.98), Style.toon(Color(0.42, 0.27, 0.15), 0.0, 0.9, false),
						pos + Vector3(-0.4 + i * 0.2, TILE_HEIGHT * 0.5 - 0.03, 0))
			Chess.Terrain.HILL:
				_add("hill%d" % shade, Vector3(0.98, TILE_HEIGHT + HILL_RAISE, 0.98),
					Style.matte(Style.TILE_HILL.darkened(shade * 0.04)), pos + Vector3(0, HILL_RAISE * 0.5, 0))
				_rocks(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.FOREST:
				_add("forest%d" % shade, Vector3(0.98, TILE_HEIGHT, 0.98),
					Style.matte(Style.TILE_FOREST.darkened(shade * 0.04)), pos)
				_trees(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.MINE:
				_add("mine", Vector3(0.98, TILE_HEIGHT, 0.98), Style.matte(Style.TILE_MINE), pos)
				_crystals(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.CASTLE:
				var light := (Chess.file_of(s) + Chess.rank_of(s)) % 2 == 0
				_add("castle%d" % int(light), Vector3(0.98, TILE_HEIGHT, 0.98),
					Style.matte(Style.TILE_CASTLE.darkened(0.0 if light else 0.12)), pos)
			Chess.Terrain.WALL:
				_add("wall", Vector3(1.0, TILE_HEIGHT + WALL_HEIGHT, 1.0), Style.matte(Color(0.40, 0.39, 0.40)),
					pos + Vector3(0, WALL_HEIGHT * 0.5, 0))
				for corner in [Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, 0.3)]:
					_add("merlon", Vector3(0.3, 0.25, 0.3), Style.matte(Color(0.46, 0.45, 0.46)),
						pos + corner + Vector3(0, top_of(t) + 0.12, 0))
			_:
				var grass := Style.GRASS_TILE.darkened(shade * 0.05)
				_add("plain%d" % shade, Vector3(0.98, TILE_HEIGHT, 0.98), Style.matte(grass), pos)
	_flush()


func _add(key: String, size: Vector3, mat: Material, pos: Vector3) -> void:
	if not _batches.has(key):
		var b := BoxMesh.new()
		b.size = size
		_batches[key] = { "mesh": b, "material": mat, "transforms": [] }
	_batches[key]["transforms"].append(Transform3D(Basis.IDENTITY, pos))


func _flush() -> void:
	for key in _batches:
		var b: Dictionary = _batches[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = b["mesh"]
		mm.instance_count = b["transforms"].size()
		for i in mm.instance_count:
			mm.set_instance_transform(i, b["transforms"][i])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = b["material"]
		add_child(mi)


## One or two small trees per forest square, at the back so units stay visible.
func _trees(top: Vector3, rng: RandomNumberGenerator) -> void:
	for corner in [Vector3(-0.28, 0, -0.28), Vector3(0.3, 0, -0.1)]:
		if rng.randf() < 0.25:
			continue
		var path: String = ENV_DIR + TREES[rng.randi() % TREES.size()] + ".gltf"
		if not ResourceLoader.exists(path):
			continue
		var tree := (load(path) as PackedScene).instantiate() as Node3D
		tree.position = top + corner
		tree.scale = Vector3.ONE * rng.randf_range(0.38, 0.5)
		tree.rotation_degrees.y = rng.randf() * 360.0
		add_child(tree)


func _rocks(top: Vector3, rng: RandomNumberGenerator) -> void:
	for i in 2:
		_add("rock", Vector3(0.14, 0.09, 0.12), Style.toon(Color(0.45, 0.42, 0.38), 0.0, 0.95, false),
			top + Vector3(rng.randf_range(-0.35, 0.35), 0.03, rng.randf_range(-0.38, -0.1)))


## A cluster of glowing crystals: the energy the miners dig.
func _crystals(top: Vector3, rng: RandomNumberGenerator) -> void:
	var glow := Style.glow(Style.CRYSTAL, 2.2)
	for i in 4:
		var mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = rng.randf_range(0.05, 0.08)
		c.height = rng.randf_range(0.22, 0.4)
		c.radial_segments = 5
		mi.mesh = c
		mi.material_override = glow
		var a := TAU * i / 4.0 + rng.randf() * 0.5
		mi.position = top + Vector3(cos(a) * 0.3, c.height * 0.4, -0.15 + sin(a) * 0.18)
		mi.rotation_degrees = Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))
		add_child(mi)
