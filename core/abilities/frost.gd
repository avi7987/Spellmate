extends Ability
## Queen (the Archwitch) - "Frost Spell": an enemy piece (not the king) that the
## queen could reach is frozen: it cannot move or use its power on the next turn.
## A frozen piece still threatens squares.


func _init() -> void:
	id = "frost"
	piece_kind = Chess.Kind.QUEEN
	duration = 2


func targets(state: GameState, from: int) -> Array:
	var q := state.piece_at(from)
	var out := []
	for d in Chess.ROOK_DIRS + Chess.BISHOP_DIRS:
		var f: int = Chess.file_of(from) + d[0]
		var r: int = Chess.rank_of(from) + d[1]
		while Chess.on_board(f, r):
			var s := Chess.sq(f, r)
			if state.is_lava(s):
				break
			var t := state.piece_at(s)
			if t != null:
				if t.color != q.color and t.kind != Chess.Kind.KING and not state.is_frozen(t):
					out.append(s)
				break
			f += d[0]
			r += d[1]
	return out


func apply(state: GameState, _from: int, target: int, events: Array) -> void:
	var t := state.piece_at(target)
	state.freezes[t.id] = state.ply + duration
	events.append({ "type": "freeze", "piece_id": t.id, "square": target })
