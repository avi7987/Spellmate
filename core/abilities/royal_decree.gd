extends Ability
## King - "Royal Decree": an adjacent friendly piece (not the king) gets a shield.
## A shielded piece cannot be captured until its owner's next turn.


func _init() -> void:
	id = "royal_decree"
	piece_kind = Chess.Kind.KING
	duration = 2


func targets(state: GameState, from: int) -> Array:
	var king := state.piece_at(from)
	var out := []
	for s in Ability.neighbors(from, Chess.KING_OFFSETS):
		var t := state.piece_at(s)
		if t != null and t.color == king.color and t.kind != Chess.Kind.KING and not state.is_shielded(t):
			out.append(s)
	return out


func apply(state: GameState, _from: int, target: int, events: Array) -> void:
	var t := state.piece_at(target)
	state.shields[t.id] = state.ply + duration
	events.append({ "type": "shield", "piece_id": t.id, "square": target })
