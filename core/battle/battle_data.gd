class_name BattleData
extends RefCounted
## Reads the real-time battle data files: heroes, spells and battle numbers.

static var _cache: Dictionary = {}


static func _load(path: String) -> Dictionary:
	if not _cache.has(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		_cache[path] = parsed if parsed is Dictionary else {}
	return _cache[path]


static func hero(id: String) -> Dictionary:
	return _load("res://data/heroes.json").get(id, {})


static func spell(id: String) -> Dictionary:
	return _load("res://data/spells.json").get(id, {})


static func is_spell(id: String) -> bool:
	return not spell(id).is_empty()


static func card(id: String) -> Dictionary:
	return spell(id) if is_spell(id) else hero(id)


static func hero_ids() -> Array:
	return _load("res://data/heroes.json").keys().filter(func(k): return not k.begins_with("_"))


static func spell_ids() -> Array:
	return _load("res://data/spells.json").keys().filter(func(k): return not k.begins_with("_"))


static func cfg() -> Dictionary:
	return _load("res://data/battle.json")


static func get_num(section: String, key: String, fallback: float = 0.0) -> float:
	return float(cfg().get(section, {}).get(key, fallback))
