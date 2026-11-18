class_name GameAction
extends RefCounted
## A single thing a player does on their turn: a chess move OR an ability.
## Actions are plain data so they can be saved, replayed or sent over a network.

enum Type { MOVE, ABILITY, PASS }

var type: int = Type.MOVE
var from: int = -1
## Destination square for a move, target square for an ability.
var to: int = -1
## Piece kind to promote to (moves only, 0 = none).
var promotion: int = 0
var ability_id: String = ""


static func move(p_from: int, p_to: int, p_promotion: int = 0) -> GameAction:
	var a := GameAction.new()
	a.type = Type.MOVE
	a.from = p_from
	a.to = p_to
	a.promotion = p_promotion
	return a


static func ability(p_id: String, p_from: int, p_target: int) -> GameAction:
	var a := GameAction.new()
	a.type = Type.ABILITY
	a.ability_id = p_id
	a.from = p_from
	a.to = p_target
	return a


static func pass_turn() -> GameAction:
	var a := GameAction.new()
	a.type = Type.PASS
	return a


func is_move() -> bool:
	return type == Type.MOVE


func equals(o: GameAction) -> bool:
	return o != null and type == o.type and from == o.from and to == o.to \
		and promotion == o.promotion and ability_id == o.ability_id


func to_dict() -> Dictionary:
	return { "type": type, "from": from, "to": to, "promotion": promotion, "ability_id": ability_id }


static func from_dict(d: Dictionary) -> GameAction:
	var a := GameAction.new()
	a.type = int(d.get("type", Type.MOVE))
	a.from = int(d.get("from", -1))
	a.to = int(d.get("to", -1))
	a.promotion = int(d.get("promotion", 0))
	a.ability_id = str(d.get("ability_id", ""))
	return a


func _to_string() -> String:
	if type == Type.ABILITY:
		return "%s:%s>%s" % [ability_id, Chess.square_name(from), Chess.square_name(to)]
	if type == Type.PASS:
		return "pass"
	return Chess.square_name(from) + Chess.square_name(to)
