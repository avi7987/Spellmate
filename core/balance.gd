class_name Balance
extends RefCounted
## Reads game-balance numbers from res://data/balance.json.
## Designers change numbers there; no code changes needed.

const PATH := "res://data/balance.json"

static var _data: Dictionary = {}


static func data() -> Dictionary:
	if _data.is_empty():
		var text := FileAccess.get_file_as_string(PATH)
		var parsed = JSON.parse_string(text)
		if parsed is Dictionary:
			_data = parsed
		else:
			push_error("Balance: could not read %s" % PATH)
			_data = { "energy": {}, "abilities": {} }
	return _data


static func energy_start() -> int:
	return int(data().get("energy", {}).get("start", 0))


static func energy_max() -> int:
	return int(data().get("energy", {}).get("max", 10))


static func energy_per_turn() -> int:
	return int(data().get("energy", {}).get("per_turn", 1))


static func energy_per_capture() -> int:
	return int(data().get("energy", {}).get("per_capture", 1))


static func ability(id: String) -> Dictionary:
	return data().get("abilities", {}).get(id, {})
