extends Ability
## Soldier (pawn) - "Shield Wall": the soldier raises its shield. Until its
## owner's next turn it gets a big defense bonus in battles (combat.brace_defense).


func _init() -> void:
	id = "brace"
	piece_kind = Chess.Kind.PAWN
	duration = 2


func targets(state: GameState, from: int) -> Array:
	return [] if state.is_braced(state.piece_at(from)) else [from]


func apply(state: GameState, from: int, _target: int, events: Array) -> void:
	var p := state.piece_at(from)
	state.braces[p.id] = state.ply + duration
	events.append({ "type": "brace", "piece_id": p.id, "square": from })
