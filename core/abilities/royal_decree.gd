extends Ability
## King - "Royal Decree": every friendly unit next to the king gets a shield.
## Shielded units cannot be attacked until their owner's next turn.


func _init() -> void:
	id = "royal_decree"
	piece_kind = Chess.Kind.KING
	duration = 2


func _allies(state: GameState, from: int) -> Array:
	var king := state.piece_at(from)
	var out := []
	for s in Ability.neighbors(from, Chess.KING_OFFSETS):
		var t := state.piece_at(s)
		if t != null and t.color == king.color and not state.is_shielded(t):
			out.append(s)
	return out


## Cast on the king's own square; it needs at least one neighbour to protect.
func targets(state: GameState, from: int) -> Array:
	return [from] if not _allies(state, from).is_empty() else []


func apply(state: GameState, from: int, _target: int, events: Array) -> void:
	for s in _allies(state, from):
		var t := state.piece_at(s)
		state.shields[t.id] = state.ply + duration
		events.append({ "type": "shield", "piece_id": t.id, "square": s })
