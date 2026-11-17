class_name PieceModelFactory
extends RefCounted
## Builds the character models.
##
## TODAY: placeholder "chibi" characters assembled from rounded shapes, already
## using the shared Style materials so they match the final look.
## LATER: drop a real model at res://assets/characters/<kind_name>.glb
## (e.g. king.glb) and it is used automatically instead of the placeholder,
## then recoloured per team by its material names (see _apply_team_colors).
##
## Model conventions: feet at the origin, facing +Z, about 1.1 units tall.

const KIND_NAMES := {
	Chess.Kind.PAWN: "pawn", Chess.Kind.KNIGHT: "knight", Chess.Kind.BISHOP: "bishop",
	Chess.Kind.ROOK: "rook", Chess.Kind.QUEEN: "queen", Chess.Kind.KING: "king",
}


static func build(kind: int, color: int) -> Node3D:
	var path := "res://assets/characters/%s.glb" % KIND_NAMES[kind]
	if ResourceLoader.exists(path):
		var scene: PackedScene = load(path)
		var model := scene.instantiate() as Node3D
		_apply_team_colors(model, color)
		return model
	var root := Node3D.new()
	root.name = "Placeholder_" + KIND_NAMES[kind]
	match kind:
		Chess.Kind.KING: _king(root, color)
		Chess.Kind.QUEEN: _witch(root, color)
		Chess.Kind.ROOK: _golem(root, color)
		Chess.Kind.BISHOP: _wizard(root, color)
		Chess.Kind.KNIGHT: _dragon(root, color)
		Chess.Kind.PAWN: _shieldbearer(root, color)
	return root


## Real models name their materials "team_metal", "team_cloth", "team_accent".
static func _apply_team_colors(node: Node, color: int) -> void:
	var t := Style.team(color)
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(i)
			if mat == null:
				continue
			match mat.resource_name:
				"team_metal": mi.set_surface_override_material(i, Style.metal(t["metal"]))
				"team_cloth": mi.set_surface_override_material(i, Style.cloth(t["cloth"]))
				"team_accent": mi.set_surface_override_material(i, Style.cloth(t["accent"]))
	for c in node.get_children():
		_apply_team_colors(c, color)


# ------------------------------------------------------------ shape helpers

static func _add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale
	parent.add_child(mi)
	return mi


static func _sphere(r: float, hemi: bool = false) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r if hemi else r * 2.0
	m.is_hemisphere = hemi
	m.radial_segments = 24
	m.rings = 12
	return m


static func _capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 20
	m.rings = 6
	return m


static func _cyl(top: float, bottom: float, h: float) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = h
	m.radial_segments = 24
	return m


static func _box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


## Shared cartoon face: big eyes and angry/determined brows.
static func _face(root: Node3D, head_y: float, head_r: float, glow_eyes: Color = Color(0, 0, 0, 0)) -> void:
	var z := head_r * 0.82
	for side in [-1.0, 1.0]:
		var x: float = side * head_r * 0.36
		if glow_eyes.a > 0.0:
			_add(root, _sphere(head_r * 0.2), Style.glow(glow_eyes, 3.0), Vector3(x, head_y + 0.01, z))
			continue
		_add(root, _sphere(head_r * 0.25), Style.toon(Style.EYE_WHITE, 0, 0.4, false), Vector3(x, head_y + 0.02, z))
		_add(root, _sphere(head_r * 0.13), Style.toon(Style.EYE_DARK, 0, 0.2, false), Vector3(x, head_y + 0.02, z + head_r * 0.15))
		_add(root, _box(Vector3(head_r * 0.42, head_r * 0.1, head_r * 0.1)), Style.toon(Style.EYE_DARK, 0, 0.5, false),
			Vector3(x, head_y + head_r * 0.36, z + 0.02), Vector3(0, 0, -side * 18.0))


static func _feet(root: Node3D, mat: Material) -> void:
	for side in [-1.0, 1.0]:
		_add(root, _sphere(0.075), mat, Vector3(side * 0.09, 0.05, 0.03), Vector3.ZERO, Vector3(1, 0.7, 1.3))


static func _hands(root: Node3D, mat: Material, y: float = 0.36, spread: float = 0.25) -> void:
	for side in [-1.0, 1.0]:
		_add(root, _sphere(0.085), mat, Vector3(side * spread, y, 0.06))


# ------------------------------------------------------------ characters

## The Golden King: wide gold armour, big crown with gems, blue cape, sword.
static func _king(root: Node3D, color: int) -> void:
	var t := Style.team(color)
	var metal := Style.metal(t["metal"])
	var cloth := Style.cloth(t["cloth"])
	_add(root, _box(Vector3(0.52, 0.55, 0.05)), cloth, Vector3(0, 0.34, -0.17), Vector3(-8, 0, 0))   # cape
	_add(root, _capsule(0.23, 0.56), metal, Vector3(0, 0.33, 0), Vector3.ZERO, Vector3(1.08, 1, 0.95))   # armour
	_add(root, _cyl(0.24, 0.27, 0.1), metal, Vector3(0, 0.16, 0))                                        # armour skirt
	_add(root, _cyl(0.2, 0.22, 0.06), cloth, Vector3(0, 0.55, 0))                                        # collar
	_add(root, _cyl(0.09, 0.09, 0.03), Style.cloth(t["accent"]), Vector3(0, 0.38, 0.235), Vector3(90, 0, 0))  # chest emblem
	_add(root, _sphere(0.24), Style.toon(Style.SKIN), Vector3(0, 0.76, 0.0))                              # head
	_add(root, _sphere(0.25), Style.toon(Style.HAIR_GOLD), Vector3(0, 0.79, -0.06), Vector3.ZERO, Vector3(1.08, 1, 0.9))  # hair
	_face(root, 0.76, 0.24)
	_add(root, _cyl(0.2, 0.18, 0.13), metal, Vector3(0, 0.98, 0))                                        # crown band
	for i in 5:
		var a := TAU * i / 5.0
		_add(root, _box(Vector3(0.07, 0.11, 0.07)), metal, Vector3(sin(a) * 0.17, 1.08, cos(a) * 0.17), Vector3(0, rad_to_deg(a), 45))
	_add(root, _sphere(0.045), Style.glow(t["cloth"], 1.2), Vector3(0, 0.99, 0.2))                         # gem
	_hands(root, metal)
	_add(root, _box(Vector3(0.07, 0.62, 0.025)), Style.metal(Color(0.92, 0.94, 0.97)), Vector3(0.3, 0.62, -0.05), Vector3(0, 0, -25))  # sword
	_add(root, _sphere(0.05), metal, Vector3(0.2, 0.36, 0.0))                                            # pommel
	_feet(root, metal)


## The Archwitch (queen): tall pointy hat, flowing dress, staff with an ice orb.
static func _witch(root: Node3D, color: int) -> void:
	var t := Style.team(color)
	var cloth := Style.cloth(t["cloth"])
	var metal := Style.metal(t["metal"])
	_add(root, _cyl(0.13, 0.3, 0.55), cloth, Vector3(0, 0.29, 0))                                       # dress
	_add(root, _cyl(0.15, 0.17, 0.05), metal, Vector3(0, 0.5, 0))                                       # belt/collar
	_add(root, _sphere(0.23), Style.toon(Style.SKIN), Vector3(0, 0.74, 0))
	_add(root, _sphere(0.25), Style.toon(Style.HAIR_DARK), Vector3(0, 0.72, -0.07), Vector3.ZERO, Vector3(1.1, 1.15, 0.85))
	_face(root, 0.74, 0.23)
	_add(root, _cyl(0.36, 0.36, 0.03), cloth, Vector3(0, 0.9, 0))                                       # hat brim
	_add(root, _cyl(0.0, 0.2, 0.5), cloth, Vector3(0, 1.15, -0.03), Vector3(-12, 0, 0))                 # hat cone
	_add(root, _cyl(0.205, 0.205, 0.05), metal, Vector3(0, 0.95, 0))                                    # hat band
	_add(root, _cyl(0.025, 0.025, 0.95), Style.toon(Color(0.45, 0.28, 0.15)), Vector3(0.3, 0.45, 0.04)) # staff
	_add(root, _sphere(0.08), Style.glow(Color(0.55, 0.9, 1.0), 2.5), Vector3(0.3, 0.96, 0.04))         # ice orb
	_hands(root, Style.toon(Style.SKIN), 0.4, 0.22)
	_feet(root, cloth)


## The Stone Golem (rook): boulder body, glowing rune, a little tower on its back.
static func _golem(root: Node3D, color: int) -> void:
	var t := Style.team(color)
	var stone := Style.toon(Style.STONE, 0.0, 0.95)
	var metal := Style.metal(t["metal"])
	_add(root, _sphere(0.3), stone, Vector3(0, 0.36, 0), Vector3.ZERO, Vector3(1.15, 1.0, 0.9))         # body
	_add(root, _cyl(0.13, 0.14, 0.4), metal, Vector3(0, 0.7, -0.2))                                       # tower
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		_add(root, _box(Vector3(0.08, 0.08, 0.08)), metal, Vector3(sin(a) * 0.11, 0.94, -0.2 + cos(a) * 0.11))
	_add(root, _sphere(0.19), stone, Vector3(0, 0.72, 0.06))                                              # head
	_face(root, 0.72, 0.19, t["rune"])
	_add(root, _box(Vector3(0.12, 0.12, 0.03)), Style.glow(t["rune"], 2.5), Vector3(0, 0.38, 0.27), Vector3(0, 0, 45))  # rune
	for side in [-1.0, 1.0]:
		_add(root, _sphere(0.15), stone, Vector3(side * 0.35, 0.5, 0.0))                                  # shoulders
		_add(root, _sphere(0.13), stone, Vector3(side * 0.37, 0.22, 0.06))                                # fists
	_add(root, _sphere(0.11), stone, Vector3(-0.12, 0.06, 0.02), Vector3.ZERO, Vector3(1, 0.6, 1.2))
	_add(root, _sphere(0.11), stone, Vector3(0.12, 0.06, 0.02), Vector3.ZERO, Vector3(1, 0.6, 1.2))


## The Mystic Wizard (bishop): long white beard, starry hat and robe.
static func _wizard(root: Node3D, color: int) -> void:
	var t := Style.team(color)
	var cloth := Style.cloth(t["cloth"])
	var metal := Style.metal(t["metal"])
	_add(root, _cyl(0.15, 0.28, 0.58), cloth, Vector3(0, 0.29, 0))                                      # robe
	_add(root, _sphere(0.22), Style.toon(Style.SKIN), Vector3(0, 0.74, 0))
	_add(root, _cyl(0.17, 0.02, 0.36), Style.toon(Style.BEARD), Vector3(0, 0.52, 0.12), Vector3(12, 0, 0))   # beard
	_add(root, _sphere(0.07), Style.toon(Style.SKIN), Vector3(0, 0.71, 0.22))                             # nose
	_face(root, 0.77, 0.21)
	_add(root, _cyl(0.32, 0.32, 0.03), cloth, Vector3(0, 0.9, 0))                                       # brim
	_add(root, _cyl(0.0, 0.2, 0.62), cloth, Vector3(0, 1.2, -0.02), Vector3(-6, 0, 0))                  # tall hat
	_add(root, _sphere(0.05), Style.glow(t["rune"], 3.0), Vector3(0, 1.1, 0.13))                          # star
	_add(root, _cyl(0.205, 0.205, 0.05), metal, Vector3(0, 0.94, 0))
	_add(root, _box(Vector3(0.18, 0.22, 0.06)), Style.cloth(t["accent"]), Vector3(-0.24, 0.36, 0.1), Vector3(0, 20, 0))  # spell book
	_hands(root, Style.toon(Style.SKIN), 0.36, 0.24)
	_feet(root, cloth)


## The Little Dragon (knight): chubby, big eyes, small wings, a saddle.
static func _dragon(root: Node3D, color: int) -> void:
	var t := Style.team(color)
	var skin := Style.toon(t["dragon"], 0.0, 0.6)
	var belly := Style.toon(t["dragon"].lightened(0.45), 0.0, 0.7)
	var metal := Style.metal(t["metal"])
	_add(root, _sphere(0.28), skin, Vector3(0, 0.3, -0.02), Vector3.ZERO, Vector3(1, 1.05, 1.1))         # body
	_add(root, _sphere(0.2), belly, Vector3(0, 0.3, 0.13), Vector3.ZERO, Vector3(1, 1.2, 0.6))           # belly
	_add(root, _cyl(0.0, 0.1, 0.45), skin, Vector3(0, 0.18, -0.35), Vector3(-70, 0, 0))                  # tail
	_add(root, _box(Vector3(0.3, 0.06, 0.24)), Style.cloth(t["cloth"]), Vector3(0, 0.54, -0.06), Vector3(-10, 0, 0))  # saddle
	for side in [-1.0, 1.0]:
		_add(root, _box(Vector3(0.36, 0.26, 0.03)), Style.cloth(t["cloth"]), Vector3(side * 0.3, 0.52, -0.12),
			Vector3(0, side * 30.0, side * 28.0))                                                       # wings
		_add(root, _cyl(0.0, 0.045, 0.16), metal, Vector3(side * 0.11, 0.98, -0.04), Vector3(-20, 0, -side * 20.0))  # horns
	_add(root, _sphere(0.23), skin, Vector3(0, 0.76, 0.02))                                              # head
	_add(root, _sphere(0.13), belly, Vector3(0, 0.68, 0.2), Vector3.ZERO, Vector3(1.2, 0.8, 1))         # snout
	for side in [-1.0, 1.0]:
		_add(root, _sphere(0.02), Style.toon(Style.EYE_DARK, 0, 0.5, false), Vector3(side * 0.05, 0.71, 0.32))  # nostrils
	_face(root, 0.82, 0.21)
	_hands(root, skin, 0.3, 0.24)
	_feet(root, skin)


## The Shieldbearer (pawn): small brave soldier with a helmet and round shield.
static func _shieldbearer(root: Node3D, color: int) -> void:
	var t := Style.team(color)
	var metal := Style.metal(t["metal"])
	var cloth := Style.cloth(t["cloth"])
	_add(root, _capsule(0.18, 0.44), cloth, Vector3(0, 0.27, 0))                                         # tunic
	_add(root, _cyl(0.17, 0.19, 0.05), Style.toon(Color(0.45, 0.28, 0.15)), Vector3(0, 0.28, 0))         # belt
	_add(root, _sphere(0.22), Style.toon(Style.SKIN), Vector3(0, 0.64, 0))
	_face(root, 0.62, 0.22)
	_add(root, _sphere(0.245, true), metal, Vector3(0, 0.68, -0.01))                                     # helmet
	_add(root, _box(Vector3(0.04, 0.14, 0.04)), metal, Vector3(0, 0.68, 0.23))                            # nose guard
	_add(root, _cyl(0.2, 0.2, 0.05), metal, Vector3(-0.1, 0.3, 0.2), Vector3(90, 0, 0))                  # shield rim
	_add(root, _cyl(0.17, 0.17, 0.06), Style.cloth(t["cloth"]), Vector3(-0.1, 0.3, 0.215), Vector3(90, 0, 0))  # shield face
	_add(root, _box(Vector3(0.05, 0.2, 0.02)), metal, Vector3(-0.1, 0.3, 0.25))                           # emblem
	_add(root, _box(Vector3(0.16, 0.05, 0.02)), metal, Vector3(-0.1, 0.33, 0.25))
	_add(root, _cyl(0.02, 0.02, 0.5), Style.toon(Color(0.45, 0.28, 0.15)), Vector3(0.22, 0.4, 0.05))     # spear
	_add(root, _cyl(0.0, 0.045, 0.12), metal, Vector3(0.22, 0.7, 0.05))
	_hands(root, Style.toon(Style.SKIN), 0.3, 0.2)
	_feet(root, Style.toon(Color(0.45, 0.28, 0.15)))
