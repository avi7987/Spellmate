class_name Piece
extends RefCounted
## One unit in the world. The `id` stays the same for the whole game, so the
## presentation layer can track it.

var id: int = 0
var kind: int = Chess.Kind.NONE
var color: int = Chess.WHITE
var hp: int = 1
var max_hp: int = 1
## This turn: has it moved / attacked (or used its power) yet?
var moved: bool = false
var acted: bool = false
## Steps walked this turn (riders hit harder after a long charge).
var steps_taken: int = 0
var has_moved: bool = false
## The power can be used again when state.ply >= this value.
var ability_ready_ply: int = 0


func _init(p_id: int = 0, p_kind: int = Chess.Kind.NONE, p_color: int = Chess.WHITE) -> void:
	id = p_id
	kind = p_kind
	color = p_color
	if kind != Chess.Kind.NONE:
		max_hp = UnitData.max_hp(kind)
		hp = max_hp


func copy() -> Piece:
	var p := Piece.new()
	p.id = id
	p.kind = kind
	p.color = color
	p.hp = hp
	p.max_hp = max_hp
	p.moved = moved
	p.acted = acted
	p.steps_taken = steps_taken
	p.has_moved = has_moved
	p.ability_ready_ply = ability_ready_ply
	return p


func is_flying() -> bool:
	return UnitData.trait_id(kind) == "flying"
