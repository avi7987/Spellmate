extends Ability
## Bishop (the Mystic Wizard) - "Teleport Swap": swaps places with any friendly
## piece (not the king) standing on the same square colour, anywhere on the board.


func _init() -> void:
	id = "swap"
	piece_kind = Chess.Kind.BISHOP


func targets(state: GameState, from: int) -> Array:
	var b := state.piece_at(from)
	var out := []
	for s in Chess.N:
		if s == from or Chess.is_light_square(s) != Chess.is_light_square(from):
			continue
		var t := state.piece_at(s)
		if t == null or t.color != b.color or t.kind == Chess.Kind.KING:
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
