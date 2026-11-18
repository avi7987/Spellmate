class_name Piece
extends RefCounted
## One piece on the board. The `id` stays the same for the whole game
## (even after promotion), so the presentation layer can track it.

var id: int = 0
var kind: int = Chess.Kind.NONE
var color: int = Chess.WHITE
var has_moved: bool = false
## The ability can be used again when state.ply >= this value.
var ability_ready_ply: int = 0


func _init(p_id: int = 0, p_kind: int = Chess.Kind.NONE, p_color: int = Chess.WHITE) -> void:
	id = p_id
	kind = p_kind
	color = p_color


func copy() -> Piece:
	var p := Piece.new(id, kind, color)
	p.has_moved = has_moved
	p.ability_ready_ply = ability_ready_ply
	return p
