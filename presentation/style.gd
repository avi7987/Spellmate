class_name Style
extends RefCounted
## The single source of the game's look: colours and materials.
## Every model (placeholder or final art) should get its materials from here,
## so everything in the game shares one consistent cartoon style.

const OUTLINE_SHADER := preload("res://presentation/shaders/outline.gdshader")

# --- Team palettes -------------------------------------------------------
const TEAMS := {
	Chess.WHITE: {
		"metal": Color(1.0, 0.76, 0.22),     # polished gold
		"cloth": Color(0.12, 0.22, 0.55),    # deep royal blue
		"accent": Color(0.97, 0.95, 0.88),   # ivory
		"dragon": Color(0.30, 0.74, 0.36),   # emerald dragon
		"rune": Color(1.0, 0.82, 0.30),
		"ui": Color(1.0, 0.78, 0.35),
	},
	Chess.BLACK: {
		"metal": Color(0.42, 0.44, 0.52),    # dark steel
		"cloth": Color(0.36, 0.14, 0.50),    # shadow purple
		"accent": Color(0.80, 0.14, 0.24),   # crimson
		"dragon": Color(0.80, 0.22, 0.20),   # crimson dragon
		"rune": Color(0.80, 0.45, 1.0),
		"ui": Color(0.72, 0.45, 1.0),
	},
}

const SKIN := Color(0.96, 0.70, 0.55)
const HAIR_GOLD := Color(1.0, 0.82, 0.25)
const HAIR_DARK := Color(0.22, 0.14, 0.24)
const BEARD := Color(0.88, 0.88, 0.92)
const STONE := Color(0.46, 0.46, 0.52)
const EYE_WHITE := Color(1, 1, 1)
const EYE_DARK := Color(0.08, 0.06, 0.08)
const OUTLINE := Color(0.10, 0.07, 0.06)

# --- Board (dark medieval stone) -------------------------------------------
const TILE_LIGHT := Color(0.64, 0.58, 0.48)   # weathered limestone
const TILE_DARK := Color(0.21, 0.22, 0.25)    # slate
const FRAME_WOOD := Color(0.17, 0.10, 0.06)   # dark oak
const FRAME_GOLD := Color(0.60, 0.44, 0.20)   # aged bronze
const GRASS := Color(0.17, 0.27, 0.14)        # dark moss
const TILE_FOREST := Color(0.20, 0.32, 0.17)
const GRASS_TILE := Color(0.30, 0.40, 0.22)
const TILE_HILL := Color(0.44, 0.40, 0.30)
const TILE_MINE := Color(0.16, 0.15, 0.20)
const TILE_CASTLE := Color(0.50, 0.49, 0.47)
const CRYSTAL := Color(0.35, 0.85, 1.0)

# --- Turn moods: the whole scene's light changes with the side to move -----
const MOOD := {
	Chess.WHITE: { "sun": Color(1.0, 0.86, 0.62), "sun_energy": 0.95, "ambient": Color(0.62, 0.55, 0.45),
		"ambient_energy": 0.42, "accent": Color(1.0, 0.76, 0.3), "tint": Color(1.0, 0.72, 0.3, 0.16) },
	Chess.BLACK: { "sun": Color(0.62, 0.62, 1.0), "sun_energy": 0.62, "ambient": Color(0.38, 0.30, 0.58),
		"ambient_energy": 0.5, "accent": Color(0.72, 0.42, 1.0), "tint": Color(0.45, 0.2, 0.75, 0.22) },
}

# --- Highlights -------------------------------------------------------------
const HL_SELECTED := Color(1.0, 0.9, 0.55, 0.95)
const HL_MOVE := Color(1.0, 0.84, 0.45, 0.95)
const HL_CAPTURE := Color(1.0, 0.28, 0.16, 1.0)
const HL_ABILITY := Color(0.75, 0.45, 1.0, 1.0)
const HL_LAST := Color(0.95, 0.8, 0.45, 0.8)
const HL_CHECK := Color(1.0, 0.12, 0.05, 0.85)
const HL_HOVER := Color(1.0, 0.95, 0.8, 0.9)
const LAVA := Color(1.0, 0.42, 0.08)
const SHIELD := Color(0.95, 0.8, 0.35, 0.3)
const ICE := Color(0.70, 0.92, 1.0, 0.45)

# --- Power themes: each power has its own colours and icon (cards, markers, effects)
const POWER_THEME := {
	"royal_decree": { "color": Color(1.0, 0.80, 0.32), "dark": Color(0.22, 0.13, 0.03), "icon": "shield" },
	"frost": { "color": Color(0.55, 0.88, 1.0), "dark": Color(0.03, 0.10, 0.24), "icon": "snowflake" },
	"stone_push": { "color": Color(0.82, 0.68, 0.50), "dark": Color(0.16, 0.12, 0.08), "icon": "boulder" },
	"swap": { "color": Color(0.82, 0.52, 1.0), "dark": Color(0.13, 0.04, 0.22), "icon": "swirl" },
	"fire_breath": { "color": Color(1.0, 0.52, 0.16), "dark": Color(0.26, 0.04, 0.02), "icon": "flame" },
	"brace": { "color": Color(0.95, 0.75, 0.40), "dark": Color(0.18, 0.12, 0.05), "icon": "wall" },
	"toil": { "color": Color(0.35, 0.85, 1.0), "dark": Color(0.03, 0.12, 0.18), "icon": "crystal" },
	"heal": { "color": Color(0.5, 1.0, 0.55), "dark": Color(0.03, 0.16, 0.06), "icon": "shield" },
}


static func power_color(id: String) -> Color:
	return POWER_THEME.get(id, {}).get("color", HL_ABILITY)


static var _cache: Dictionary = {}


static func team(color: int) -> Dictionary:
	return TEAMS[color]


## Cartoon material: toon shading + dark outline.
static func toon(color: Color, metallic: float = 0.0, roughness: float = 0.7, outline: bool = true) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [color.to_html(), metallic, roughness, outline]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metallic
	m.roughness = roughness
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	# The camera looks straight down and the sun is high, so flat surfaces would
	# mirror the sun. Keep specular for metals only.
	m.metallic_specular = 0.5 if metallic > 0.5 else 0.05
	m.rim_enabled = outline
	m.rim = 0.25
	m.rim_tint = 0.6
	if outline:
		var o := ShaderMaterial.new()
		o.shader = OUTLINE_SHADER
		o.set_shader_parameter("outline_color", OUTLINE)
		m.next_pass = o
	_cache[key] = m
	return m


static func metal(color: Color) -> StandardMaterial3D:
	return toon(color, 0.85, 0.28)


static func cloth(color: Color) -> StandardMaterial3D:
	return toon(color, 0.0, 0.85)


## Matte material for the board and scenery (no shine, no outline).
static func matte(color: Color) -> StandardMaterial3D:
	var key := "matte|%s" % color.to_html()
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	_cache[key] = m
	return m


static func glow(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var key := "glow|%s|%.1f" % [color.to_html(), energy]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_cache[key] = m
	return m


## See-through unshaded material for highlights and magic effects.
static func overlay(color: Color, unshaded: bool = true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	return m
