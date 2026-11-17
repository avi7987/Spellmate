class_name AbilityRegistry
extends RefCounted
## The list of all abilities, one per piece kind.

const SCRIPTS := [
	preload("res://core/abilities/charge.gd"),
	preload("res://core/abilities/fire_breath.gd"),
	preload("res://core/abilities/swap.gd"),
	preload("res://core/abilities/stone_push.gd"),
	preload("res://core/abilities/frost.gd"),
	preload("res://core/abilities/royal_decree.gd"),
]

static var _by_kind: Dictionary = {}
static var _by_id: Dictionary = {}


static func _ensure_loaded() -> void:
	if not _by_id.is_empty():
		return
	for script in SCRIPTS:
		var a: Ability = script.new()
		a.load_balance()
		_by_kind[a.piece_kind] = a
		_by_id[a.id] = a


static func for_kind(kind: int) -> Ability:
	_ensure_loaded()
	return _by_kind.get(kind, null)


static func by_id(id: String) -> Ability:
	_ensure_loaded()
	return _by_id.get(id, null)


static func all() -> Array:
	_ensure_loaded()
	return _by_id.values()
