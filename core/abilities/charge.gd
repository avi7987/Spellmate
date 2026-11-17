extends Ability
## Pawn (the Shieldbearer) - "Charge": moves 2 squares forward from anywhere
## (not only from the start), without capturing. Both squares must be empty and
## not lava, and it cannot be used to reach the promotion rank.


func _init() -> void:
	id = "charge"
	piece_kind = Chess.Kind.PAWN


func targets(state: GameState, from: int) -> Array:
	var p := state.piece_at(from)
	var dir := Chess.forward(p.color)
	var start_rank := 1 if p.color == Chess.WHITE else 6
	var f := Chess.file_of(from)
	var r := Chess.rank_of(from)
	if r == start_rank:
		return []  # a normal double step already does this
	var r2 := r + 2 * dir
	if not Chess.on_board(f, r2) or r2 == Chess.promotion_rank(p.color):
		return []
	var s1 := Chess.sq(f, r + dir)
	var s2 := Chess.sq(f, r2)
	for s in [s1, s2]:
		if state.piece_at(s) != null or state.is_lava(s):
			return []
	return [s2]


func apply(state: GameState, from: int, target: int, events: Array) -> void:
	var p := state.piece_at(from)
	state.board[target] = p
	state.board[from] = null
	p.has_moved = true
	events.append({ "type": "move", "piece_id": p.id, "from": from, "to": target })
