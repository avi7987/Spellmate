extends Ability
## Rook (the Stone Golem) - "Stone Shove": pushes an orthogonally adjacent enemy
## piece (not the king, not shielded) one square directly away, if that square
## is empty and not lava. Pawns cannot be pushed onto the first/last rank.


func _init() -> void:
	id = "stone_push"
	piece_kind = Chess.Kind.ROOK


func push_destination(state: GameState, from: int, target: int) -> int:
	var df := Chess.file_of(target) - Chess.file_of(from)
	var dr := Chess.rank_of(target) - Chess.rank_of(from)
	var f := Chess.file_of(target) + df
	var r := Chess.rank_of(target) + dr
	if not Chess.on_board(f, r):
		return -1
	var dest := Chess.sq(f, r)
	if state.piece_at(dest) != null or state.is_lava(dest):
		return -1
	var t := state.piece_at(target)
	if t.kind == Chess.Kind.PAWN and (r == 0 or r == 7):
		return -1
	return dest


func targets(state: GameState, from: int) -> Array:
	var rook := state.piece_at(from)
	var out := []
	for s in Ability.neighbors(from, Chess.ROOK_DIRS):
		var t := state.piece_at(s)
		if t != null and t.color != rook.color and t.kind != Chess.Kind.KING \
				and not state.is_shielded(t) and push_destination(state, from, s) >= 0:
			out.append(s)
	return out


func apply(state: GameState, from: int, target: int, events: Array) -> void:
	var dest := push_destination(state, from, target)
	var t := state.piece_at(target)
	state.board[dest] = t
	state.board[target] = null
	t.has_moved = true
	events.append({ "type": "push", "piece_id": t.id, "from": target, "to": dest })
