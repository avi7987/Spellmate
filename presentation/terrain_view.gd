class_name TerrainView
extends Node3D
## Draws the map squares (a terrain array, see MapGen): stone and grass tiles,
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


## The centre of square (x, y) of a w x h map at height 0 (y = 0 is the bottom / Sun side).
static func cell_xz(x: int, y: int, w: int, h: int) -> Vector3:
	return Vector3(x - (w - 1) / 2.0, 0, (h - 1) / 2.0 - y)


var _biome: Dictionary = {}
var _props := "trees"


func _col(key: String, fallback: Color) -> Color:
	var c: Dictionary = _biome.get("colors", {})
	return Color.html(c[key]) if c.has(key) else fallback


## `biome` = an entry of data/biomes.json: colours of the ground, water (or lava /
## chocolate) and which little things grow on forest squares.
func build(terrain: PackedInt32Array, w: int = Chess.W, h: int = Chess.H, biome: Dictionary = {}) -> void:
	for c in get_children():
		c.queue_free()
	_batches.clear()
	_biome = biome
	_props = biome.get("props", "trees")
	var water := ShaderMaterial.new()
	water.shader = WATER_SHADER
	var wc := _col("water", Color(0.18, 0.45, 0.58))
	water.set_shader_parameter("deep", wc.darkened(0.45))
	water.set_shader_parameter("shallow", wc)
	water.set_shader_parameter("foam", wc.lightened(0.5))
	if biome.get("lava_river", false):
		water.set_shader_parameter("foam", Color(1.0, 0.85, 0.3))
	var plain_c := _col("plain", Style.GRASS_TILE)
	var forest_c := _col("forest", Style.TILE_FOREST)
	var hill_c := _col("hill", Style.TILE_HILL)
	var special_c := _col("special", plain_c)
	var sp_name: String = biome.get("special", {}).get("name", "")
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for s in w * h:
		var t: int = terrain[s]
		var pos := cell_xz(s % w, s / w, w, h)
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
					Style.matte(hill_c.darkened(shade * 0.04)), pos + Vector3(0, HILL_RAISE * 0.5, 0))
				_rocks(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.FOREST:
				_add("forest%d" % shade, Vector3(0.98, TILE_HEIGHT, 0.98),
					Style.matte(forest_c.darkened(shade * 0.04)), pos)
				_trees(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.SPECIAL:
				_special_tile(pos, special_c, shade, rng)
			Chess.Terrain.SHRINE:
				_add("plain%d" % shade, Vector3(0.98, TILE_HEIGHT, 0.98), Style.matte(plain_c.darkened(shade * 0.05)), pos)
			Chess.Terrain.MINE:
				_add("mine", Vector3(0.98, TILE_HEIGHT, 0.98), Style.matte(Style.TILE_MINE), pos)
				_crystals(pos + Vector3(0, top_of(t), 0), rng)
			Chess.Terrain.CASTLE:
				var light := (s % w + s / w) % 2 == 0
				_add("castle%d" % int(light), Vector3(0.98, TILE_HEIGHT, 0.98),
					Style.matte(Style.TILE_CASTLE.darkened(0.0 if light else 0.12)), pos)
			Chess.Terrain.WALL:
				_add("wall", Vector3(1.0, TILE_HEIGHT + WALL_HEIGHT, 1.0), Style.matte(Color(0.40, 0.39, 0.40)),
					pos + Vector3(0, WALL_HEIGHT * 0.5, 0))
				for corner in [Vector3(-0.3, 0, -0.3), Vector3(0.3, 0, 0.3)]:
					_add("merlon", Vector3(0.3, 0.25, 0.3), Style.matte(Color(0.46, 0.45, 0.46)),
						pos + corner + Vector3(0, top_of(t) + 0.12, 0))
			_:
				var grass := plain_c.darkened(shade * 0.05)
				_add("plain%d" % shade, Vector3(0.98, TILE_HEIGHT, 0.98), Style.matte(grass), pos)
				if rng.randf() < 0.06:
					_tiny(pos + Vector3(0, top_of(t), 0), rng)
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


## One or two small trees per forest square (or what grows in this world:
## dead trees, black rocks, snowy pines, cacti, lollipops, glowing mushrooms),
## at the back of the square so units stay visible.
func _trees(top: Vector3, rng: RandomNumberGenerator) -> void:
	for corner in [Vector3(-0.28, 0, -0.28), Vector3(0.3, 0, -0.1)]:
		if rng.randf() < 0.25:
			continue
		if _props != "trees":
			_world_prop(top + corner, rng)
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


func _mi(mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	mi.scale = scl
	add_child(mi)
	return mi


func _cyl(top_r: float, bottom_r: float, h: float, seg: int = 10) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bottom_r
	c.height = h
	c.radial_segments = seg
	return c


func _box_m(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _ball(r: float) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.radial_segments = 12
	m.rings = 6
	return m


## What grows on a forest square in each world.
func _world_prop(p: Vector3, rng: RandomNumberGenerator) -> void:
	var sc := rng.randf_range(0.8, 1.15)
	match _props:
		"dead_trees":
			var bark := Style.toon(Color(0.24, 0.2, 0.15), 0.0, 0.9, false)
			_mi(_cyl(0.03, 0.07, 0.7 * sc), bark, p + Vector3(0, 0.35 * sc, 0), Vector3(0, 0, rng.randf_range(-8, 8)))
			for k in 3:
				_mi(_cyl(0.01, 0.03, 0.3), bark, p + Vector3(0, (0.4 + k * 0.12) * sc, 0), Vector3(0, k * 120.0, 55))
			if rng.randf() < 0.5:
				_mi(_ball(0.08), Style.glow(Color(0.6, 1.0, 0.4), 1.4), p + Vector3(0.12, 0.08, 0.1))   # a swamp light
		"rocks_fire":
			_mi(_ball(0.2 * sc), Style.toon(Color(0.12, 0.1, 0.1), 0.0, 0.9, false), p + Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.1, 0.8, 1))
			_mi(_cyl(0.0, 0.07, 0.35 * sc, 5), Style.toon(Color(0.15, 0.12, 0.12), 0.0, 0.9, false), p + Vector3(0.1, 0.25, -0.05))
			_mi(_ball(0.05), Style.glow(Color(1.0, 0.45, 0.1), 2.5), p + Vector3(-0.05, 0.22, 0.12))
		"snow_trees":
			var pine := Style.toon(Color(0.18, 0.38, 0.32), 0.0, 0.8, false)
			var snow := Style.toon(Color(0.95, 0.97, 1.0), 0.0, 0.6, false)
			_mi(_cyl(0.03, 0.04, 0.2), Style.toon(Color(0.35, 0.24, 0.15), 0, 0.9, false), p + Vector3(0, 0.1, 0))
			for k in 3:
				var r := (0.26 - k * 0.07) * sc
				_mi(_cyl(0.0, r, 0.3 * sc), pine, p + Vector3(0, (0.3 + k * 0.18) * sc, 0))
				_mi(_cyl(0.0, r * 0.6, 0.12 * sc), snow, p + Vector3(0, (0.42 + k * 0.18) * sc, 0))
		"cactus":
			var green := Style.toon(Color(0.3, 0.55, 0.25), 0.0, 0.7, false)
			var caps := CapsuleMesh.new()
			caps.radius = 0.08 * sc
			caps.height = 0.6 * sc
			_mi(caps, green, p + Vector3(0, 0.3 * sc, 0))
			var arm := CapsuleMesh.new()
			arm.radius = 0.05 * sc
			arm.height = 0.25 * sc
			_mi(arm, green, p + Vector3(0.12 * sc, 0.38 * sc, 0))
			_mi(arm, green, p + Vector3(-0.12 * sc, 0.3 * sc, 0))
		"lollipops":
			var cols := [Color(1.0, 0.35, 0.5), Color(0.5, 0.85, 1.0), Color(1.0, 0.85, 0.3), Color(0.7, 1.0, 0.5)]
			_mi(_cyl(0.015, 0.015, 0.55 * sc), Style.toon(Color(0.98, 0.95, 0.9), 0, 0.5, false), p + Vector3(0, 0.27 * sc, 0))
			var disc := _cyl(0.17 * sc, 0.17 * sc, 0.06, 20)
			_mi(disc, Style.toon(cols[rng.randi() % cols.size()], 0.1, 0.3, false), p + Vector3(0, 0.6 * sc, 0), Vector3(90, rng.randf() * 360.0, 0))
			_mi(_cyl(0.08 * sc, 0.08 * sc, 0.07, 16), Style.toon(Color.WHITE, 0, 0.3, false), p + Vector3(0, 0.6 * sc, 0), Vector3(90, 0, 0))
		"graves":
			var stone := Style.toon(Color(0.55, 0.58, 0.6), 0.0, 0.9, false)
			if rng.randf() < 0.6:
				_mi(_box_m(Vector3(0.24 * sc, 0.34 * sc, 0.07)), stone, p + Vector3(0, 0.17 * sc, 0), Vector3(-8, rng.randf_range(-20, 20), rng.randf_range(-8, 8)))
				_mi(_cyl(0.12 * sc, 0.12 * sc, 0.07, 12), stone, p + Vector3(0, 0.34 * sc, 0), Vector3(90, 0, 0))
			else:
				_mi(_cyl(0.02, 0.03, 0.6 * sc), Style.toon(Color(0.2, 0.2, 0.22), 0.5, 0.5, false), p + Vector3(0, 0.3 * sc, 0))
				_mi(_ball(0.08), Style.glow(Color(0.5, 1.0, 0.9), 2.0), p + Vector3(0, 0.62 * sc, 0))   # a ghost lantern
		"mushrooms":
			var cap_c: Color = [Color(0.3, 0.95, 0.85), Color(0.75, 0.45, 1.0), Color(1.0, 0.5, 0.8)][rng.randi() % 3]
			_mi(_cyl(0.05 * sc, 0.07 * sc, 0.35 * sc), Style.toon(Color(0.9, 0.88, 0.8), 0, 0.6, false), p + Vector3(0, 0.17 * sc, 0))
			var cap := SphereMesh.new()
			cap.radius = 0.22 * sc
			cap.height = 0.22 * sc
			cap.is_hemisphere = true
			_mi(cap, Style.glow(cap_c, 1.3), p + Vector3(0, 0.34 * sc, 0))
		_:
			pass


## A little detail on an open square: a flower, a pebble, a bone, a candy...
func _tiny(p: Vector3, rng: RandomNumberGenerator) -> void:
	var off := Vector3(rng.randf_range(-0.3, 0.3), 0.03, rng.randf_range(-0.3, 0.3))
	match _props:
		"trees":
			_mi(_ball(0.04), Style.toon([Color(1, 0.9, 0.3), Color(1, 0.5, 0.6), Color(0.9, 0.9, 1)][rng.randi() % 3], 0, 0.5, false), p + off)
		"cactus", "dead_trees", "rocks_fire":
			_mi(_ball(0.05), Style.toon(_col("hill", Color.GRAY).darkened(0.2), 0, 0.9, false), p + off, Vector3.ZERO, Vector3(1.2, 0.6, 1))
		"snow_trees":
			_mi(_ball(0.06), Style.toon(Color.WHITE, 0, 0.5, false), p + off, Vector3.ZERO, Vector3(1.4, 0.5, 1.2))
		"lollipops":
			_mi(_ball(0.05), Style.toon([Color(1, 0.3, 0.4), Color(0.4, 0.8, 1), Color(1, 0.9, 0.3)][rng.randi() % 3], 0.1, 0.3, false), p + off)
		"mushrooms":
			_mi(_ball(0.03), Style.glow(Color(0.4, 1.0, 0.9), 1.6), p + off)
		"graves":
			_mi(_ball(0.04), Style.toon(Color(0.9, 0.9, 0.85), 0, 0.6, false), p + off, Vector3.ZERO, Vector3(1.6, 0.5, 0.6))   # a little bone


## The world's special ground: mud, lava, ice, deep sand, candy or glowing spores.
func _special_tile(pos: Vector3, c: Color, shade: int, rng: RandomNumberGenerator) -> void:
	var top := pos + Vector3(0, top_of(Chess.Terrain.SPECIAL), 0)
	match _props:
		"rocks_fire":   # lava: glowing
			_add("lava", Vector3(0.98, TILE_HEIGHT, 0.98), Style.glow(c, 1.6), pos)
			_add("crust", Vector3(0.3, 0.03, 0.22), Style.toon(Color(0.15, 0.1, 0.08), 0, 0.9, false), top + Vector3(rng.randf_range(-0.25, 0.25), 0.01, rng.randf_range(-0.25, 0.25)))
		"snow_trees":   # ice: shiny
			_add("ice%d" % shade, Vector3(0.98, TILE_HEIGHT, 0.98), Style.toon(c.lightened(shade * 0.04), 0.3, 0.1, false), pos)
		"lollipops":    # candy: stripes
			_add("candy", Vector3(0.98, TILE_HEIGHT, 0.98), Style.toon(c, 0.1, 0.3, false), pos)
			for i in 3:
				_add("stripe", Vector3(0.98, 0.012, 0.1), Style.toon(Color(1.0, 0.4, 0.55), 0, 0.3, false), top + Vector3(0, 0.005, -0.3 + i * 0.3))
		"graves":       # ghost mist: glowing, misty ground
			_add("mist", Vector3(0.98, TILE_HEIGHT, 0.98), Style.glow(c.darkened(0.7), 0.4), pos)
			_add("wisp", Vector3(0.5, 0.02, 0.3), Style.overlay(Color(c.r, c.g, c.b, 0.35)), top + Vector3(rng.randf_range(-0.2, 0.2), 0.04, rng.randf_range(-0.2, 0.2)))
		"mushrooms":    # glowing spores
			_add("spore_ground", Vector3(0.98, TILE_HEIGHT, 0.98), Style.matte(_col("plain", c).darkened(0.1)), pos)
			for i in 3:
				_add("spore", Vector3(0.07, 0.07, 0.07), Style.glow(c, 2.0), top + Vector3(rng.randf_range(-0.35, 0.35), 0.06, rng.randf_range(-0.35, 0.35)))
		_:              # mud, sand, flowers: a darker / lighter patch with bumps
			_add("special%d" % shade, Vector3(0.98, TILE_HEIGHT, 0.98), Style.matte(c.darkened(shade * 0.05)), pos)
			_add("bump", Vector3(0.22, 0.04, 0.16), Style.matte(c.darkened(0.15)), top + Vector3(rng.randf_range(-0.3, 0.3), 0.0, rng.randf_range(-0.3, 0.3)))
