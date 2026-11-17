class_name AiPlayer
extends RefCounted
## A computer opponent that understands the super powers.
## Alpha-beta search over legal actions with a simple evaluation.
## Levels: 0 = Squire (easy), 1 = Knight (medium), 2 = King (hard).

const PIECE_VALUE := {
	Chess.Kind.PAWN: 100, Chess.Kind.KNIGHT: 320, Chess.Kind.BISHOP: 330,
	Chess.Kind.ROOK: 500, Chess.Kind.QUEEN: 900, Chess.Kind.KING: 0,
}
const MATE := 100000
const ENERGY_VALUE := 12

var rng := RandomNumberGenerator.new()


func choose_action(state: GameState, level: int) -> GameAction:
	var actions := Rules.legal_actions(state)
	if actions.is_empty():
		return null
	var depth := 1 if level <= 0 else 2
	var noise := 60 if level <= 0 else (15 if level == 1 else 0)
	_order(state, actions)
	var best: GameAction = null
	var best_score := -MATE * 10
	for a in actions:
		var c := state.clone(false)
		Rules.apply_action(c, a)
		var score := -_search(c, depth - 1, -MATE * 10, -best_score, 1, level >= 2)
		score += rng.randi_range(-noise, noise)
		if score > best_score:
			best_score = score
			best = a
	return best


func _search(state: GameState, depth: int, alpha: int, beta: int, ply_from_root: int, captures_ext: bool) -> int:
	if depth <= 0:
		return _quiesce(state, alpha, beta, 2 if captures_ext else 0)
	var actions := Rules.legal_actions(state)
	if actions.is_empty():
		return -MATE + ply_from_root if Rules.in_check(state, state.side_to_move) else 0
	_order(state, actions)
	for a in actions:
		var c := state.clone(false)
		Rules.apply_action(c, a)
		var score := -_search(c, depth - 1, -beta, -alpha, ply_from_root + 1, captures_ext)
		if score >= beta:
			return beta
		alpha = maxi(alpha, score)
	return alpha


## Looks a little further at captures only, so the AI doesn't blunder pieces.
func _quiesce(state: GameState, alpha: int, beta: int, depth_left: int) -> int:
	var stand := evaluate(state)
	if depth_left <= 0 or stand >= beta:
		return stand
	alpha = maxi(alpha, stand)
	var moves := Rules.legal_moves(state).filter(func(m): return state.piece_at(m.to) != null)
	for m in moves:
		var c := state.clone(false)
		Rules.apply_action(c, m)
		var score := -_quiesce(c, -beta, -alpha, depth_left - 1)
		if score >= beta:
			return beta
		alpha = maxi(alpha, score)
	return alpha


## Score from the point of view of the side to move.
func evaluate(state: GameState) -> int:
	var score := 0
	for s in 64:
		var p := state.piece_at(s)
		if p == null:
			continue
		var v: int = PIECE_VALUE[p.kind]
		# Small bonus for central squares and advanced pawns.
		var f := Chess.file_of(s)
		var r := Chess.rank_of(s)
		var center := 6 - (absi(2 * f - 7) + absi(2 * r - 7)) / 2
		if p.kind != Chess.Kind.KING:
			v += center * 4
		if p.kind == Chess.Kind.PAWN:
			v += (r if p.color == Chess.WHITE else 7 - r) * 6
		if state.is_frozen(p):
			v -= 20
		score += v if p.color == state.side_to_move else -v
	var me := state.side_to_move
	score += (int(state.energy[me]) - int(state.energy[Chess.other(me)])) * ENERGY_VALUE
	if Rules.in_check(state, me):
		score -= 30
	return score


## Captures first (most valuable victim), then moves, then abilities.
func _order(state: GameState, actions: Array) -> void:
	actions.sort_custom(func(a, b): return _guess(state, a) > _guess(state, b))


func _guess(state: GameState, a: GameAction) -> int:
	if a.type == GameAction.Type.ABILITY:
		return 50
	var victim := state.piece_at(a.to)
	if victim != null:
		return 1000 + PIECE_VALUE[victim.kind] - PIECE_VALUE[state.piece_at(a.from).kind] / 10
	return 100 if a.promotion != 0 else 0
