extends Ability
## Queen - "Frost Storm": an enemy unit (not the king) that the
## queen could reach, and every enemy standing next to it, is frozen: it cannot move or use its power on the next turn.
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


## Frost storm: the target AND every enemy next to it freeze (kings never do).
func apply(state: GameState, from: int, target: int, events: Array) -> void:
	var me := state.piece_at(from).color
	events.append({ "type": "frost_storm", "square": target })
	for s in [target] + Ability.neighbors(target, Chess.KING_OFFSETS):
		var t := state.piece_at(s)
		if t != null and t.color != me and t.kind != Chess.Kind.KING:
			state.freezes[t.id] = state.ply + duration
			events.append({ "type": "freeze", "piece_id": t.id, "square": s })
