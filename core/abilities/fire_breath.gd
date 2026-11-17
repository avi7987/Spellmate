extends Ability
## Knight (the Little Dragon) - "Fire Breath": an empty adjacent square becomes
## lava for 2 rounds. No piece may land on lava or slide through it
## (knights/dragons can still jump over it).


func _init() -> void:
	id = "fire_breath"
	piece_kind = Chess.Kind.KNIGHT
	duration = 4


func targets(state: GameState, from: int) -> Array:
	var out := []
	for s in Ability.neighbors(from, Chess.KING_OFFSETS):
		if state.piece_at(s) == null and not state.is_lava(s):
			out.append(s)
	return out


func apply(state: GameState, from: int, target: int, events: Array) -> void:
	state.hazards[target] = state.ply + duration
	events.append({ "type": "lava", "square": target, "from": from })
