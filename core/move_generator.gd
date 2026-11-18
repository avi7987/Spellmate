class_name MoveGen
extends RefCounted
## Where can a unit go? Movement looks like chess, with a maximum range per unit
## type (data/units.json) and terrain rules:
##   - water cannot be entered (bridges can); burning squares neither
##   - a sliding unit that enters a forest must stop there
##   - units block the way; moving onto an enemy = attacking it (a battle)
##   - knights jump over everything
##   - shielded enemies cannot be attacked, frozen units cannot move


static func pseudo_moves(state: GameState, out: Array) -> void:
	for s in Chess.N:
		var p: Piece = state.board[s]
		if p != null and p.color == state.side_to_move:
			piece_moves(state, s, out)


static func piece_moves(state: GameState, from: int, out: Array) -> void:
	var p: Piece = state.board[from]
	if p == null or state.is_frozen(p):
		return
	for to in reachable(state, from):
		out.append(GameAction.move(from, to))


## Every square the unit on `from` can move to or attack.
static func reachable(state: GameState, from: int) -> Array:
	var p: Piece = state.board[from]
	var out := []
	if p == null:
		return out
	var kind_move := UnitData.move_type(p.kind)
	var max_range := UnitData.move_range(p.kind)
	match kind_move:
		"knight":
			_jumps(state, from, p, out)
		"orth":
			_slides(state, from, p, Chess.ROOK_DIRS, max_range, out)
		"diag":
			_slides(state, from, p, Chess.BISHOP_DIRS, max_range, out)
		_:
			_slides(state, from, p, Chess.ROOK_DIRS + Chess.BISHOP_DIRS, max_range, out)
	return out


## Can `p` end its move on `to`? (empty walkable square, or an enemy it may attack)
static func _can_enter(state: GameState, p: Piece, to: int) -> bool:
	if not state.is_walkable(to):
		return false
	var t: Piece = state.board[to]
	return t == null or (t.color != p.color and not state.is_shielded(t))


static func _jumps(state: GameState, from: int, p: Piece, out: Array) -> void:
	for o in Chess.KNIGHT_OFFSETS:
		var f: int = Chess.file_of(from) + o[0]
		var r: int = Chess.rank_of(from) + o[1]
		if Chess.on_board(f, r) and _can_enter(state, p, Chess.sq(f, r)):
			out.append(Chess.sq(f, r))


static func _slides(state: GameState, from: int, p: Piece, dirs: Array, max_range: int, out: Array) -> void:
	for d in dirs:
		var f: int = Chess.file_of(from)
		var r: int = Chess.rank_of(from)
		for step in max_range:
			f += d[0]
			r += d[1]
			if not Chess.on_board(f, r):
				break
			var to := Chess.sq(f, r)
			if not state.is_walkable(to):
				break
			var t: Piece = state.board[to]
			if t != null:
				if t.color != p.color and not state.is_shielded(t):
					out.append(to)
				break
			out.append(to)
			if state.terrain[to] == Chess.Terrain.FOREST:
				break  # forests stop sliding units


## Units of `color` that could attack square `s` on their next move.
static func attackers_of(state: GameState, s: int, color: int) -> Array:
	var out := []
	for from in Chess.N:
		var p: Piece = state.board[from]
		if p == null or p.color != color or state.is_frozen(p):
			continue
		if Chess.distance(from, s) > maxi(2, UnitData.move_range(p.kind)):
			continue
		if reachable(state, from).has(s):
			out.append(from)
	return out
