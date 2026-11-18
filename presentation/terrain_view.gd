class_name TerrainView
extends Node3D
## Draws the battlefield squares from GameState.terrain: stone tiles, forests
## with small trees, raised hills, the river with bridges, glowing crystal mines
## and the two castles' courtyards.

const TILE_HEIGHT := 0.2
const HILL_RAISE := 0.14
const WATER_DROP := 0.12
const TREES := ["tree_single_A", "tree_single_B"]
const ENV_DIR := "res://assets/environment/kaykit/"
const WATER_SHADER := preload("res://presentation/shaders/water.gdshader")

var _water_mat: ShaderMaterial


## Height of the top of a square (where units stand).
static func top_of(terrain: int) -> float:
	match terrain:
		Chess.Terrain.HILL:
			return TILE_HEIGHT * 0.5 + HILL_RAISE
		Chess.Terrain.WATER:
			return TILE_HEIGHT * 0.5 - WATER_DROP
	return TILE_HEIGHT * 0.5


func build(terrain: PackedInt32Array) -> void:
	for c in get_children():
		c.queue_free()
	_water_mat = ShaderMaterial.new()
	_water_mat.shader = WATER_SHADER
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for s in Chess.N:
		var t: int = terrain[s]
		var pos := BoardView.square_xz(s)
		var shade := rng.randf() * 0.07
		match t:
			Chess.Terrain.WATER:
				_box(Vector3(1.0, 0.06, 1.0), pos + Vector3(0, -WATER_DROP + 0.04, 0), _water_mat)
				_box(Vector3(1.0, 0.06, 1.0), pos + Vector3(0, -0.12, 0), Style.matte(Color(0.12, 0.1, 0.08)))
			Chess.Terrain.BRIDGE:
				_box(Vector3(1.0, 0.06, 1.0), pos + Vector3(0, -WATER_DROP + 0.04, 0), _water_mat)
				_bridge(pos)
			Chess.Terrain.HILL:
				_box(Vector3(0.98, TILE_HEIGHT + HILL_RAISE, 0.98), pos + Vector3(0, HILL_RAISE * 0.5, 0),
					Style.matte(Style.TILE_HILL.darkened(shade)))
				_rocks(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.FOREST:
				_box(Vector3(0.98, TILE_HEIGHT, 0.98), pos, Style.matte(Style.TILE_FOREST.darkened(shade)))
				_trees(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.MINE:
				_box(Vector3(0.98, TILE_HEIGHT, 0.98), pos, Style.matte(Style.TILE_MINE.darkened(shade)))
				_crystals(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.CASTLE:
				var sun_side := Chess.rank_of(s) < Chess.H / 2
				var team := Chess.WHITE if sun_side else Chess.BLACK
				_box(Vector3(0.98, TILE_HEIGHT, 0.98), pos, Style.matte(Style.TILE_CASTLE.darkened(shade)))
				_box(Vector3(0.86, 0.01, 0.86), pos + Vector3(0, TILE_HEIGHT * 0.5 + 0.005, 0),
					Style.matte(Style.team(team)["ui"].darkened(0.55)))
			_:
				var c: Color = Style.TILE_LIGHT if Chess.is_light_square(s) else Style.TILE_DARK
				_box(Vector3(0.98, TILE_HEIGHT, 0.98), pos, Style.matte(c.darkened(shade)))


func _box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _bridge(pos: Vector3) -> void:
	var wood := Style.toon(Color(0.42, 0.27, 0.15), 0.0, 0.9, false)
	for i in 5:
		_box(Vector3(0.18, 0.06, 0.98), pos + Vector3(-0.4 + i * 0.2, TILE_HEIGHT * 0.5 - 0.03, 0), wood)
	var rail := Style.toon(Color(0.30, 0.19, 0.10), 0.0, 0.9, false)
	_box(Vector3(0.06, 0.12, 0.98), pos + Vector3(-0.47, TILE_HEIGHT * 0.5 + 0.04, 0), rail)
	_box(Vector3(0.06, 0.12, 0.98), pos + Vector3(0.47, TILE_HEIGHT * 0.5 + 0.04, 0), rail)


## Small trees in the back corners so units standing in the forest stay visible.
func _trees(top: Vector3, rng: RandomNumberGenerator) -> void:
	for corner in [Vector3(-0.32, 0, -0.3), Vector3(0.3, 0, -0.34), Vector3(0.36, 0, 0.18)]:
		var path: String = ENV_DIR + TREES[rng.randi() % TREES.size()] + ".gltf"
		if not ResourceLoader.exists(path):
			continue
		var holder := Node3D.new()
		holder.position = top + corner
		holder.rotation_degrees.x = -PieceView.LEAN_DEGREES * 0.6
		add_child(holder)
		var tree := (load(path) as PackedScene).instantiate() as Node3D
		tree.scale = Vector3.ONE * rng.randf_range(0.34, 0.44)
		tree.rotation_degrees.y = rng.randf() * 360.0
		holder.add_child(tree)


func _rocks(top: Vector3, rng: RandomNumberGenerator) -> void:
	var stone := Style.toon(Color(0.45, 0.42, 0.38), 0.0, 0.95, false)
	for i in 3:
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = rng.randf_range(0.06, 0.1)
		sp.height = sp.radius * 1.3
		sp.radial_segments = 6
		sp.rings = 3
		mi.mesh = sp
		mi.material_override = stone
		mi.position = top + Vector3(rng.randf_range(-0.38, 0.38), 0.0, rng.randf_range(-0.38, -0.1))
		add_child(mi)


## A cluster of glowing crystals: the energy source the miners work on.
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
	var light := OmniLight3D.new()
	light.light_color = Style.CRYSTAL
	light.light_energy = 0.6
	light.omni_range = 1.2
	light.position = top + Vector3(0, 0.3, 0)
	add_child(light)
