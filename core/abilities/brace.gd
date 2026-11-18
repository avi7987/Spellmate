extends Ability
## Soldier (pawn) - "Shield Wall": the soldier raises its shield. Until its
## owner's next turn it gets a big defense bonus in battles (combat.brace_defense).


func _init() -> void:
	id = "brace"
	piece_kind = Chess.Kind.PAWN
	duration = 2


func targets(state: GameState, from: int) -> Array:
	return [] if state.is_braced(state.piece_at(from)) else [from]


## The soldier and every friendly soldier next to it raise their shields.
func apply(state: GameState, from: int, _target: int, events: Array) -> void:
	var p := state.piece_at(from)
	for s in [from] + Ability.neighbors(from, Chess.KING_OFFSETS):
		var t := state.piece_at(s)
		if t != null and t.color == p.color and t.kind == p.kind:
			state.braces[t.id] = state.ply + duration
			events.append({ "type": "brace", "piece_id": t.id, "square": s })
