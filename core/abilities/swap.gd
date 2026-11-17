extends Ability
## Bishop (the Mystic Wizard) - "Teleport Swap": swaps places with any friendly
## piece (not the king) standing on the same square colour, anywhere on the board.
## A pawn may not be swapped onto the first or last rank.


func _init() -> void:
	id = "swap"
	piece_kind = Chess.Kind.BISHOP


func targets(state: GameState, from: int) -> Array:
	var b := state.piece_at(from)
	var out := []
	var from_rank := Chess.rank_of(from)
	for s in 64:
		if s == from or Chess.is_light_square(s) != Chess.is_light_square(from):
			continue
		var t := state.piece_at(s)
		if t == null or t.color != b.color or t.kind == Chess.Kind.KING:
			continue
		if t.kind == Chess.Kind.PAWN and (from_rank == 0 or from_rank == 7):
			continue
		out.append(s)
	return out


func apply(state: GameState, from: int, target: int, events: Array) -> void:
	var b := state.piece_at(from)
	var t := state.piece_at(target)
	state.board[from] = t
	state.board[target] = b
	b.has_moved = true
	t.has_moved = true
	events.append({ "type": "swap", "piece_id": b.id, "other_id": t.id, "from": from, "to": target })
