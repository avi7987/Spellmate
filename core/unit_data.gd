class_name UnitData
extends RefCounted
## Unit types (movement, range, battle bonuses) from res://data/units.json
## and the battlefield layout from res://data/map.json.

const UNITS_PATH := "res://data/units.json"
const MAP_PATH := "res://data/map.json"

static var _units: Dictionary = {}
static var _map: Dictionary = {}


static func _load(path: String) -> Dictionary:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is Dictionary:
		return parsed
	push_error("UnitData: could not read " + path)
	return {}


static func unit(kind: int) -> Dictionary:
	if _units.is_empty():
		_units = _load(UNITS_PATH)
	return _units.get(Chess.KIND_NAMES.get(kind, ""), {})


static func max_hp(kind: int) -> int:
	return int(unit(kind).get("hp", 10))


static func attack(kind: int) -> int:
	return int(unit(kind).get("atk", 3))


static func armor(kind: int) -> int:
	return int(unit(kind).get("def", 0))


static func move_points(kind: int) -> int:
	return int(unit(kind).get("move", 3))


static func attack_range(kind: int) -> int:
	return int(unit(kind).get("range", 1))


static func cost(kind: int) -> int:
	return int(unit(kind).get("cost", 0))


static func vision(kind: int) -> int:
	return int(unit(kind).get("vision", 4))


static func trait_id(kind: int) -> String:
	return unit(kind).get("trait", "")


static func value(kind: int) -> int:
	return int(unit(kind).get("value", 100))


## Unit types that can be recruited at the palace gate, cheapest first.
static func recruitable() -> Array:
	var out := []
	for k in Chess.KIND_NAMES:
		if cost(k) > 0:
			out.append(k)
	out.sort_custom(func(a, b): return cost(a) < cost(b))
	return out


static func structure(kind: String) -> Dictionary:
	return Balance.data().get("structures", {}).get(kind, {})


static func map_data() -> Dictionary:
	if _map.is_empty():
		_map = _load(MAP_PATH)
	return _map


## Terrain of every square, from the map rows.
static func terrain_grid() -> PackedInt32Array:
	var grid := PackedInt32Array()
	grid.resize(Chess.N)
	var rows: Array = map_data().get("rows", [])
	for i in rows.size():
		var rank := Chess.H - 1 - i
		var row: String = rows[i]
		for f in mini(row.length(), Chess.W):
			grid[Chess.sq(f, rank)] = Chess.TERRAIN_CHARS.get(row[f], Chess.Terrain.PLAIN)
	return grid


## Gates ("G") and towers ("T") on the map: [[square, "gate"/"tower"], ...]
static func map_structures() -> Array:
	var out := []
	var rows: Array = map_data().get("rows", [])
	for i in rows.size():
		var rank := Chess.H - 1 - i
		var row: String = rows[i]
		for f in mini(row.length(), Chess.W):
			if row[f] == "G":
				out.append([Chess.sq(f, rank), "gate"])
			elif row[f] == "T":
				out.append([Chess.sq(f, rank), "tower"])
	return out


## Starting army of the Sun: square -> kind. The Void gets the mirror image.
static func starting_army() -> Dictionary:
	var out := {}
	var army: Dictionary = map_data().get("army", {})
	for name in army:
		out[Chess.parse_square(name)] = Chess.kind_from_name(army[name])
	return out
