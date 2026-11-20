class_name PieceModelFactory
extends RefCounted
## Builds the character models.
##
## Which model plays which piece is set in res://data/characters.json
## (model file, visible props, size, and animation names). Today those are
## KayKit characters (CC0) recoloured per team by tools/recolor_textures.py.
## If a model is missing, a simple placeholder made of shapes is used instead.
##
## Model conventions: feet at the origin, facing +Z.
## The returned node carries metadata:
##   "anims": Dictionary  (idle/move/attack/cast/hit/death/victory -> animation name)
##   "player": AnimationPlayer or null

const DATA_PATH := "res://data/characters.json"
const TEAM_SUFFIX := { Chess.WHITE: "light", Chess.BLACK: "shadow" }

static var _defs: Dictionary = {}
static var _materials: Dictionary = {}


static func definition_named(id: String, color: int) -> Dictionary:
	if _defs.is_empty():
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_defs = parsed if parsed is Dictionary else { "_": {} }
	return _defs.get(TEAM_SUFFIX[color], {}).get(id, {})


## Builds the model of a hero by its id in data/heroes.json ("soldier", "dragon"...).
static func build_hero(id: String, color: int) -> Node3D:
	var def := definition_named(id, color)
	var path: String = def.get("model", "")
	if path != "" and ResourceLoader.exists(path):
		return _build_from_model(def, color)
	var root := Node3D.new()
	root.name = "Placeholder_" + id
	match id:
		"king": _king(root, color)
		"queen": _witch(root, color)
		"dragon": _dragon(root, color)
		"ballista": _ballista(root, color)
		_: _shieldbearer(root, color)
	root.scale = Vector3.ONE * float(def.get("scale", 1.0))
	root.set_meta("anims", {})
	root.set_meta("player", null)
	return root


static func _build_from_model(def: Dictionary, color: int) -> Node3D:
	var model := (load(def["model"]) as PackedScene).instantiate() as Node3D
	var shown: Array = def.get("show", [])
	var tint := Color.html(def.get("tint", "#ffffff"))
	var mat := _team_material(def.get("texture", ""), color, def.get("king_texture", false), tint)
	for a in def.get("attach", []):
		_attach_prop(model, a.get("model", ""), a.get("bone", ""), _team_material(a.get("texture", ""), color, false, tint))
	var eyes := Style.glow(Style.team(color)["rune"], 3.0)
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		if mi.has_meta("attached"):
			continue
		var is_prop: bool = mi.get_parent() is BoneAttachment3D
		mi.visible = not is_prop or shown.has(String(mi.name))
		if def.get("glow_eyes", false) and String(mi.name).ends_with("Eyes"):
			mi.material_override = eyes
		elif mat != null:
			mi.material_override = mat
	if def.get("crown", false):
		_add_crown(model, color)
	for e in def.get("extras", []):
		_add_extra(model, String(e), color)
	var s := float(def.get("scale", 0.5))
	model.scale = Vector3.ONE * s
	var anims := {}
	for key in ["idle", "move", "attack", "cast", "hit", "death", "victory"]:
		if def.has(key):
			anims[key] = def[key]
	var players := model.find_children("*", "AnimationPlayer", true, false)
	model.set_meta("anims", anims)
	model.set_meta("player", players[0] if players.size() > 0 else null)
	return model


## Puts an extra prop (weapon, shield...) on a bone, e.g. "handslot.r".
static func _attach_prop(model: Node3D, path: String, bone: String, mat: Material) -> void:
	if not ResourceLoader.exists(path):
		return
	var att := _bone(model, bone)
	if att == null:
		return
	var prop := (load(path) as PackedScene).instantiate() as Node3D
	att.add_child(prop)
	for mi in prop.find_children("*", "MeshInstance3D", true, false) + ([prop] if prop is MeshInstance3D else []):
		mi.set_meta("attached", true)
		if mat != null:
			mi.material_override = mat


## A BoneAttachment3D on the named bone (reuses one if it exists).
static func _bone(model: Node3D, bone: String) -> BoneAttachment3D:
	for b in model.find_children("*", "BoneAttachment3D", true, false):
		if b.bone_name == bone:
			return b
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty() or skels[0].find_bone(bone) < 0:
		return null
	var att := BoneAttachment3D.new()
	att.bone_name = bone
	skels[0].add_child(att)
	return att


## One shared material per (texture, team, tint): toon shading + outline, like the rest of the game.
static func _team_material(tex_name: String, color: int, king: bool = false, tint: Color = Color.WHITE) -> Material:
	if tex_name == "":
		return null
	var suffix: String = TEAM_SUFFIX[color]
	if king:
		suffix += "_king"
	var tex_path := "res://assets/characters/kaykit/%s_%s.png" % [tex_name, suffix]
	var key := tex_path + tint.to_html()
	if _materials.has(key):
		return _materials[key]
	if not ResourceLoader.exists(tex_path):
		return null
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex_path)
	m.albedo_color = tint
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	m.roughness = 0.6
	m.metallic_specular = 0.25
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.5
	var o := ShaderMaterial.new()
	o.shader = Style.OUTLINE_SHADER
	o.set_shader_parameter("outline_color", Style.OUTLINE)
	o.set_shader_parameter("thickness", 0.02)
	m.next_pass = o
	_materials[key] = m
	return m


## Accessories built from shapes so every hero type has its own silhouette.
## Head-bone space: the top of a KayKit head is about y = 0.9; +Z is the face.
static func _add_extra(model: Node3D, what: String, color: int) -> void:
	var t := Style.team(color)
	var metal := Style.metal(t["metal"])
	var cloth := Style.cloth(t["cloth"])
	var wood := Style.toon(Color(0.45, 0.28, 0.15), 0.0, 0.85)
	var head := _bone(model, "head")
	var hand_r := _bone(model, "handslot.r")
	var hand_l := _bone(model, "handslot.l")
	var chest := _bone(model, "chest")
	match what:
		"beard":
			if head: _add(head, _cyl(0.32, 0.05, 0.5), Style.toon(Style.BEARD), Vector3(0, 0.05, 0.38), Vector3(18, 0, 0))
		"big_beard":
			if head:
				_add(head, _cyl(0.32, 0.06, 0.55), Style.toon(Color(0.75, 0.35, 0.12)), Vector3(0, 0.05, 0.42), Vector3(20, 0, 0))
		"long_hair":
			if head: _add(head, _capsule(0.42, 1.2), Style.toon(Style.HAIR_DARK if color == 1 else Style.HAIR_GOLD), Vector3(0, 0.25, -0.25), Vector3(15, 0, 0), Vector3(1.15, 1, 0.7))
		"tiara":
			if head:
				_add(head, _cyl(0.5, 0.5, 0.08), metal, Vector3(0, 0.85, 0.02))
				for i in 3:
					_add(head, _cyl(0.0, 0.09, 0.28 - absf(i - 1) * 0.1), metal, Vector3((i - 1) * 0.2, 1.0, 0.45))
				_add(head, _sphere(0.08), Style.glow(Color(0.55, 0.9, 1.0), 2.0), Vector3(0, 0.95, 0.52))
		"kettle_hat":
			if head:
				_add(head, _cyl(0.7, 0.7, 0.06), metal, Vector3(0, 0.95, 0))
				_add(head, _sphere(0.5, true), metal, Vector3(0, 0.95, 0))
		"plume":
			if head:
				for i in 5:
					_add(head, _sphere(0.2 - i * 0.02), Style.cloth(Color(0.85, 0.15, 0.12)), Vector3(0, 1.3 + sin(i * 0.6) * 0.35, -0.1 - i * 0.22), Vector3.ZERO, Vector3(0.45, 1.0, 1.0))
		"feather_hat":
			if head:
				_add(head, _cyl(0.75, 0.75, 0.05), cloth, Vector3(0, 0.85, 0), Vector3(-6, 0, 0))
				_add(head, _cyl(0.4, 0.5, 0.35), cloth, Vector3(0, 1.0, 0))
				_add(head, _box(Vector3(0.08, 0.9, 0.18)), Style.toon(Color(0.9, 0.2, 0.15)), Vector3(0.35, 1.3, -0.25), Vector3(-35, 0, -20))
		"quiver":
			if chest:
				_add(chest, _cyl(0.18, 0.18, 0.9), wood, Vector3(0.15, 0.5, -0.45), Vector3(-20, 0, -15))
				for i in 3:
					_add(chest, _box(Vector3(0.08, 0.3, 0.02)), Style.toon(Color(0.95, 0.95, 0.9)), Vector3(0.05 + i * 0.1, 1.05, -0.6), Vector3(-20, 0, -15))
		"pickaxe":
			if hand_r:
				_add(hand_r, _cyl(0.05, 0.05, 1.1), wood, Vector3(0, 0.35, 0))
				_add(hand_r, _cyl(0.02, 0.09, 0.9), Style.metal(Color(0.7, 0.72, 0.78)), Vector3(0, 0.85, 0), Vector3(0, 0, 90), Vector3(1, 1, 0.8))
		"mining_helmet":
			if head:
				_add(head, _sphere(0.62, true), Style.toon(Color(0.95, 0.75, 0.15), 0.3, 0.5), Vector3(0, 0.55, 0))
				_add(head, _cyl(0.7, 0.7, 0.06), Style.toon(Color(0.95, 0.75, 0.15), 0.3, 0.5), Vector3(0, 0.55, 0))
				_add(head, _cyl(0.14, 0.14, 0.12), Style.glow(Color(1.0, 0.95, 0.6), 3.0), Vector3(0, 0.85, 0.55), Vector3(90, 0, 0))
		"crystal_sack":
			if chest:
				_add(chest, _sphere(0.42), Style.toon(Color(0.55, 0.42, 0.28)), Vector3(0, 0.45, -0.55))
				for i in 3:
					_add(chest, _cyl(0.0, 0.12, 0.45), Style.glow(Style.CRYSTAL, 1.6), Vector3(-0.15 + i * 0.15, 0.9, -0.55), Vector3(0, 0, -20 + i * 20))
		"halo_heal":
			if head:
				var halo := TorusMesh.new()
				halo.inner_radius = 0.45
				halo.outer_radius = 0.55
				_add(head, halo, Style.glow(Color(0.5, 1.0, 0.55), 2.2), Vector3(0, 1.45, 0))
		"heart_orb":
			if hand_r: _add(hand_r, _sphere(0.2), Style.glow(Color(0.45, 1.0, 0.5), 1.4), Vector3(0, 1.0, 0))
		"orb_ice_staff":
			if hand_r: _add(hand_r, _sphere(0.28), Style.glow(Color(0.55, 0.9, 1.0), 1.5), Vector3(0, 1.75, 0))
		"orb_ice_hand":
			if hand_l: _add(hand_l, _sphere(0.25), Style.glow(Color(0.6, 0.9, 1.0), 1.5), Vector3(0, 0.3, 0.1))
		"snow_crown":
			if head:
				for i in 5:
					var a := TAU * i / 5.0
					_add(head, _cyl(0.0, 0.1, 0.45), Style.glow(Color(0.7, 0.95, 1.0), 1.4), Vector3(sin(a) * 0.45, 1.25, cos(a) * 0.45))
		"orb_fire_hand":
			if hand_r:
				_add(hand_r, _sphere(0.26), Style.glow(Color(1.0, 0.5, 0.12), 1.8), Vector3(0, 0.35, 0.1))
				_add(hand_r, _cyl(0.0, 0.2, 0.45), Style.glow(Color(1.0, 0.8, 0.25), 2.5), Vector3(0, 0.65, 0.1))
		"flame_hat":
			if head:
				for i in 3:
					_add(head, _cyl(0.0, 0.16 - i * 0.03, 0.5), Style.glow(Color(1.0, 0.45 + i * 0.15, 0.1), 2.4), Vector3((i - 1) * 0.12, 2.05, -0.55), Vector3(-45, 0, (i - 1) * -25))
		"mask":
			if head: _add(head, _box(Vector3(0.75, 0.2, 0.1)), Style.cloth(Color(0.08, 0.06, 0.08)), Vector3(0, 0.38, 0.5))
		"belly":
			if chest: _add(chest, _sphere(0.6), Style.toon(Style.SKIN), Vector3(0, 0.0, 0.25), Vector3.ZERO, Vector3(1, 0.9, 0.7))


static func _head_attachment(model: Node3D) -> BoneAttachment3D:
	for b in model.find_children("*", "BoneAttachment3D", true, false):
		if b.bone_name == "head":
			return b
	var skels := model.find_children("*", "Skeleton3D", true, false)
	if skels.is_empty():
		return null
	var head := BoneAttachment3D.new()
	head.bone_name = "head"
	skels[0].add_child(head)
	return head


## A big gold crown with gems on the head bone (KayKit has none, so we build one).
static func _add_crown(model: Node3D, color: int) -> void:
	var head: BoneAttachment3D = null
	for b in model.find_children("*", "BoneAttachment3D", true, false):
		if b.bone_name == "head":
			head = b
	if head == null:
		var skels := model.find_children("*", "Skeleton3D", true, false)
		if skels.is_empty():
			return
		head = BoneAttachment3D.new()
		head.bone_name = "head"
		skels[0].add_child(head)
	var crown := Node3D.new()
	crown.name = "Crown"
	crown.position = Vector3(0, 0.95, 0)
	head.add_child(crown)
	var gold := Style.metal(Color(1.0, 0.78, 0.2) if color == Chess.WHITE else Color(0.85, 0.62, 0.2))
	_add(crown, _cyl(0.42, 0.38, 0.28), gold, Vector3.ZERO)
	for i in 6:
		var a := TAU * i / 6.0
		_add(crown, _cyl(0.0, 0.11, 0.28), gold, Vector3(sin(a) * 0.36, 0.26, cos(a) * 0.36))
		_add(crown, _sphere(0.05), gold, Vector3(sin(a) * 0.36, 0.42, cos(a) * 0.36))
	var gem := Style.glow(Style.team(color)["cloth"].lightened(0.2), 1.2)
	_add(crown, _sphere(0.09), gem, Vector3(0, 0.02, 0.4))
	_add(crown, _sphere(0.07), gem, Vector3(0.38, 0.02, 0.12))
	_add(crown, _sphere(0.07), gem, Vector3(-0.38, 0.02, 0.12))


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


## The Dragon: big, a little scary and very cute. Chunky body with belly plates,
## a curved neck, horned head with big eyes and fangs, spikes along the back,
## a spade-tipped tail, clawed legs and big membrane wings ("WingL"/"WingR",
## flapped by UnitView). Sun = emerald and gold, Void = shadow purple and crimson.
static func _dragon(root: Node3D, color: int) -> void:
	var sun := color == Chess.WHITE
	var skin := Style.toon(Color(0.16, 0.50, 0.30) if sun else Color(0.27, 0.13, 0.36), 0.0, 0.55)
	var skin_dark := Style.toon(Color(0.10, 0.34, 0.20) if sun else Color(0.17, 0.07, 0.24), 0.0, 0.6)
	var belly := Style.toon(Color(0.96, 0.80, 0.42) if sun else Color(0.78, 0.20, 0.26), 0.0, 0.5)
	var spike := Style.toon(Color(1.0, 0.78, 0.25) if sun else Color(0.85, 0.25, 0.30), 0.3, 0.4)
	var horn := Style.toon(Color(0.98, 0.93, 0.80), 0.0, 0.4)
	var membrane := Style.toon(Color(0.78, 0.36, 0.12) if sun else Color(0.50, 0.10, 0.28), 0.0, 0.7)
	membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
	var eye_glow := Color(1.0, 0.85, 0.2) if sun else Color(1.0, 0.25, 0.45)
	# body and belly plates
	_add(root, _sphere(0.46), skin, Vector3(0, 0.62, -0.05), Vector3.ZERO, Vector3(1.0, 0.92, 1.3))
	_add(root, _sphere(0.4), belly, Vector3(0, 0.55, 0.12), Vector3.ZERO, Vector3(0.82, 0.85, 1.05))
	for i in 4:
		_add(root, _box(Vector3(0.5 - abs(i - 1.5) * 0.06, 0.035, 0.12)), Style.toon((Color(0.85, 0.65, 0.3) if sun else Color(0.6, 0.12, 0.18)), 0, 0.5, false),
			Vector3(0, 0.4 + i * 0.12, 0.46 - i * 0.01), Vector3(-30 + i * 12, 0, 0), Vector3(0.9, 1, 0.6))
	# legs with claws
	for side in [-1.0, 1.0]:
		for front in [1.0, -1.0]:
			var lp := Vector3(side * 0.3, 0.2, front * 0.32 - 0.05)
			_add(root, _sphere(0.17), skin, lp + Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1, 1.3, 1.1))
			_add(root, _sphere(0.14), skin_dark, Vector3(lp.x, 0.07, lp.z + 0.05), Vector3.ZERO, Vector3(1.1, 0.6, 1.4))
			for c in 3:
				_add(root, _cyl(0.0, 0.035, 0.11), horn, Vector3(lp.x + (c - 1) * 0.06, 0.05, lp.z + 0.22), Vector3(90, 0, 0))
	# neck
	for i in 3:
		_add(root, _sphere(0.23 - i * 0.015), skin, Vector3(0, 0.9 + i * 0.17, 0.32 + i * 0.12))
		_add(root, _sphere(0.15), belly, Vector3(0, 0.86 + i * 0.17, 0.42 + i * 0.12), Vector3.ZERO, Vector3(1, 1, 0.6))
	# head (named so it can lunge when breathing fire)
	var head := Node3D.new()
	head.name = "Head"
	head.position = Vector3(0, 1.42, 0.68)
	root.add_child(head)
	_add(head, _sphere(0.3), skin, Vector3.ZERO, Vector3.ZERO, Vector3(1.05, 0.92, 1.05))
	_add(head, _sphere(0.2), skin, Vector3(0, -0.07, 0.28), Vector3.ZERO, Vector3(1.15, 0.78, 1.25))   # snout
	_add(head, _sphere(0.17), belly, Vector3(0, -0.15, 0.28), Vector3.ZERO, Vector3(1.0, 0.45, 1.15))   # jaw
	for side in [-1.0, 1.0]:
		_add(head, _sphere(0.035), Style.toon(Style.EYE_DARK, 0, 0.5, false), Vector3(side * 0.08, -0.02, 0.5))   # nostrils
		_add(head, _cyl(0.0, 0.035, 0.1), horn, Vector3(side * 0.1, -0.2, 0.4), Vector3(180, 0, 0))        # fangs
		# big cute eyes with a glowing ring and a determined brow
		_add(head, _sphere(0.11), Style.toon(Style.EYE_WHITE, 0, 0.3, false), Vector3(side * 0.15, 0.08, 0.2))
		_add(head, _sphere(0.065), Style.glow(eye_glow, 1.6), Vector3(side * 0.155, 0.08, 0.27))
		_add(head, _sphere(0.04), Style.toon(Style.EYE_DARK, 0, 0.2, false), Vector3(side * 0.16, 0.08, 0.315), Vector3.ZERO, Vector3(0.35, 1.5, 1))
		_add(head, _box(Vector3(0.2, 0.05, 0.08)), skin_dark, Vector3(side * 0.14, 0.17, 0.27), Vector3(0, 0, side * 28.0))
		# curved horns: three cones bending backwards
		for k in 3:
			_add(head, _cyl(0.06 - k * 0.018, 0.08 - k * 0.018, 0.16), horn,
				Vector3(side * (0.17 + k * 0.03), 0.24 + k * 0.1, -0.08 - k * 0.11), Vector3(-35 - k * 22, 0, -side * 12.0))
		_add(head, _cyl(0.0, 0.05, 0.14), spike, Vector3(side * 0.28, 0.0, 0.0), Vector3(0, 0, -side * 75.0))   # cheek frills
	# back spikes from neck to tail
	for i in 7:
		var z := 0.7 - i * 0.2
		var y := 1.25 - i * 0.1 if i < 3 else 1.02 - (i - 3) * 0.13
		_add(root, _cyl(0.0, 0.08 - i * 0.004, 0.2), spike, Vector3(0, y, z - 0.25), Vector3(-15, 0, 0))
	# tail curling back, with a spade tip
	var tail := Node3D.new()
	tail.name = "Tail"
	tail.position = Vector3(0, 0.55, -0.6)
	root.add_child(tail)
	var tp := Vector3.ZERO
	for i in 6:
		tp += Vector3(sin(i * 0.5) * 0.08, -0.06 + i * 0.01, -0.16)
		_add(tail, _sphere(0.17 - i * 0.022), skin, tp)
	var spade := _cyl(0.0, 0.16, 0.32)
	spade.radial_segments = 4
	_add(tail, spade, spike, tp + Vector3(0.0, 0.0, -0.2), Vector3(-90, 0, 0), Vector3(1, 1, 0.3))
	# wings: arm bones + a scalloped membrane, pivoting at the shoulders
	for side in [-1.0, 1.0]:
		var wing := Node3D.new()
		wing.name = "WingL" if side < 0 else "WingR"
		wing.position = Vector3(side * 0.3, 1.0, -0.05)
		root.add_child(wing)
		var tips := [Vector3(0.95, 0.85, -0.25), Vector3(1.2, 0.3, -0.55), Vector3(0.85, -0.2, -0.75)]
		var edge := [Vector3(0.1, 0.2, 0.0), tips[0], Vector3(0.75, 0.38, -0.42), tips[1], Vector3(0.7, 0.0, -0.6), tips[2], Vector3(0.2, -0.25, -0.5)]
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for i in edge.size() - 1:
			for v in [Vector3.ZERO, edge[i], edge[i + 1]]:
				st.add_vertex(Vector3(v.x * side, v.y, v.z))
		st.generate_normals()
		var mem := MeshInstance3D.new()
		mem.mesh = st.commit()
		mem.material_override = membrane
		wing.add_child(mem)
		for t2 in tips:
			var tip: Vector3 = Vector3(t2.x * side, t2.y, t2.z)
			var bone := MeshInstance3D.new()
			bone.mesh = _cyl(0.018, 0.035, tip.length())
			bone.material_override = skin_dark
			bone.position = tip / 2.0
			bone.look_at_from_position(tip / 2.0, tip, Vector3.UP if absf(tip.normalized().y) < 0.95 else Vector3.FORWARD)
			bone.rotate_object_local(Vector3.RIGHT, PI / 2.0)
			wing.add_child(bone)
			_add(wing, _cyl(0.0, 0.04, 0.12), horn, tip, Vector3(0, 0, -side * 60.0))
		wing.rotation_degrees = Vector3(0, 0, -side * 28.0)
		wing.scale = Vector3.ONE * 1.25
		wing.set_meta("base_z", wing.rotation.z)


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


## The Ballista: a wooden siege crossbow on wheels with a big bolt.
static func _ballista(root: Node3D, color: int) -> void:
	var t := Style.team(color)
	var wood := Style.toon(Color(0.42, 0.27, 0.15), 0.0, 0.85)
	var metal := Style.metal(t["metal"])
	_add(root, _box(Vector3(0.5, 0.12, 0.7)), wood, Vector3(0, 0.22, 0))                               # frame
	for x in [-0.28, 0.28]:
		for z in [-0.22, 0.22]:
			_add(root, _cyl(0.12, 0.12, 0.06), wood, Vector3(x, 0.13, z), Vector3(0, 0, 90))           # wheels
	_add(root, _box(Vector3(0.12, 0.12, 0.75)), wood, Vector3(0, 0.38, 0.05), Vector3(-12, 0, 0))     # rail
	_add(root, _box(Vector3(0.9, 0.07, 0.07)), wood, Vector3(0, 0.45, 0.3), Vector3(0, 0, 0))          # bow arms
	for side in [-1.0, 1.0]:
		_add(root, _box(Vector3(0.05, 0.05, 0.3)), metal, Vector3(side * 0.43, 0.45, 0.18), Vector3(0, side * 30.0, 0))
	_add(root, _cyl(0.025, 0.025, 0.8), metal, Vector3(0, 0.46, 0.1), Vector3(90, 0, 0))               # bolt
	_add(root, _cyl(0.0, 0.05, 0.12), metal, Vector3(0, 0.46, 0.52), Vector3(90, 0, 0))                # bolt tip
	_add(root, _box(Vector3(0.3, 0.2, 0.03)), Style.cloth(t["cloth"]), Vector3(0, 0.42, -0.36))          # team shield

