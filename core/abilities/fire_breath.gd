extends Ability
## Knight - "Burning Arrow": an empty adjacent square and the empty squares around
## it (a plus shape) catch fire for 2 rounds.
## No unit may enter or pass through fire (knights can still jump over it).


func _init() -> void:
	id = "fire_breath"
	piece_kind = Chess.Kind.KNIGHT
	duration = 4


func targets(state: GameState, from: int) -> Array:
	var out := []
	for s in Ability.neighbors(from, Chess.KING_OFFSETS):
		if state.piece_at(s) == null and state.is_walkable(s):
			out.append(s)
	return out


## Firestorm: the target square and the empty squares around it (a plus shape) burn.
func apply(state: GameState, from: int, target: int, events: Array) -> void:
	events.append({ "type": "firestorm", "square": target, "from": from })
	for s in [target] + Ability.neighbors(target, Chess.ROOK_DIRS):
		if state.piece_at(s) == null and state.is_walkable(s):
			state.hazards[s] = state.ply + duration
			events.append({ "type": "lava", "square": s, "from": from })
