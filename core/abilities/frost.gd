extends Ability
## Queen - "Frost Spell": an enemy unit (not the king) that the
## queen could reach is frozen: it cannot move or use its power on the next turn.
## A frozen piece still threatens squares.


func _init() -> void:
	id = "frost"
	piece_kind = Chess.Kind.QUEEN
	duration = 2


func targets(state: GameState, from: int) -> Array:
	var q := state.piece_at(from)
	var out := []
	var reach := UnitData.move_range(q.kind)
	for d in Chess.ROOK_DIRS + Chess.BISHOP_DIRS:
		var f: int = Chess.file_of(from) + d[0]
		var r: int = Chess.rank_of(from) + d[1]
		var steps := 0
		while Chess.on_board(f, r) and steps < reach:
			steps += 1
			var s := Chess.sq(f, r)
			if not state.is_walkable(s):
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
