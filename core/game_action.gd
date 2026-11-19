class_name GameAction
extends RefCounted
## One thing a player does during a turn: move a unit, attack, use a power,
## recruit a new unit at the palace gate, or end the turn.
## Actions are plain data so they can be saved, replayed or sent over a network.

enum Type { MOVE, ABILITY, END_TURN, ATTACK, RECRUIT }

var type: int = Type.MOVE
var from: int = -1
## Destination (move), target (attack/ability) or spawn square (recruit).
var to: int = -1
## Unit kind to recruit.
var kind: int = 0
var ability_id: String = ""


static func move(p_from: int, p_to: int) -> GameAction:
	var a := GameAction.new()
	a.type = Type.MOVE
	a.from = p_from
	a.to = p_to
	return a


static func attack(p_from: int, p_target: int) -> GameAction:
	var a := GameAction.new()
	a.type = Type.ATTACK
	a.from = p_from
	a.to = p_target
	return a


static func ability(p_id: String, p_from: int, p_target: int) -> GameAction:
	var a := GameAction.new()
	a.type = Type.ABILITY
	a.ability_id = p_id
	a.from = p_from
	a.to = p_target
	return a


static func recruit(p_kind: int, p_square: int) -> GameAction:
	var a := GameAction.new()
	a.type = Type.RECRUIT
	a.kind = p_kind
	a.to = p_square
	return a


static func end_turn() -> GameAction:
	var a := GameAction.new()
	a.type = Type.END_TURN
	return a


func is_move() -> bool:
	return type == Type.MOVE


func equals(o: GameAction) -> bool:
	return o != null and type == o.type and from == o.from and to == o.to \
		and kind == o.kind and ability_id == o.ability_id


func to_dict() -> Dictionary:
	return { "type": type, "from": from, "to": to, "kind": kind, "ability_id": ability_id }


static func from_dict(d: Dictionary) -> GameAction:
	var a := GameAction.new()
	a.type = int(d.get("type", Type.MOVE))
	a.from = int(d.get("from", -1))
	a.to = int(d.get("to", -1))
	a.kind = int(d.get("kind", 0))
	a.ability_id = str(d.get("ability_id", ""))
	return a


func _to_string() -> String:
	match type:
		Type.ABILITY:
			return "%s:%s>%s" % [ability_id, Chess.square_name(from), Chess.square_name(to)]
		Type.END_TURN:
			return "end"
		Type.ATTACK:
			return "%sx%s" % [Chess.square_name(from), Chess.square_name(to)]
		Type.RECRUIT:
			return "+%s@%s" % [Chess.KIND_NAMES.get(kind, "?"), Chess.square_name(to)]
	return Chess.square_name(from) + Chess.square_name(to)
