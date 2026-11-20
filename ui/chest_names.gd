class_name ChestNames
extends RefCounted

const NAMES := { "wood": "עץ", "silver": "כסף", "gold": "זהב" }
const COLORS := { "wood": Color(0.62, 0.42, 0.22), "silver": Color(0.78, 0.8, 0.86), "gold": Color(1.0, 0.8, 0.3) }


static func name_of(type: String) -> String:
	return NAMES.get(type, type)
