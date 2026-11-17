class_name MoveGen
extends RefCounted
## Generates pseudo-legal chess moves (moves that may still leave the own king
## in check - Rules filters those out) and answers "is this square attacked?".
##
## Spellmate twists handled here:
## - Lava squares block movement like a wall: nothing may land on or slide through them.
## - Shielded pieces cannot be captured.
## - Frozen pieces cannot move (but still attack).


static func pseudo_moves(state: GameState, out: Array) -> void:
	for s in 64:
		var p: Piece = state.board[s]
		if p != null and p.color == state.side_to_move:
			piece_moves(state, s, out)


static func piece_moves(state: GameState, from: int, out: Array) -> void:
	var p: Piece = state.board[from]
	if p == null or state.is_frozen(p):
		return
	match p.kind:
		Chess.Kind.PAWN:
			_pawn_moves(state, from, p, out)
		Chess.Kind.KNIGHT:
			_step_moves(state, from, p, Chess.KNIGHT_OFFSETS, out)
		Chess.Kind.BISHOP:
			_slide_moves(state, from, p, Chess.BISHOP_DIRS, out)
		Chess.Kind.ROOK:
			_slide_moves(state, from, p, Chess.ROOK_DIRS, out)
		Chess.Kind.QUEEN:
			_slide_moves(state, from, p, Chess.ROOK_DIRS, out)
			_slide_moves(state, from, p, Chess.BISHOP_DIRS, out)
		Chess.Kind.KING:
			_step_moves(state, from, p, Chess.KING_OFFSETS, out)
			_castle_moves(state, from, p, out)


## Can a piece of `p` land on square `to`? (empty, or a capturable enemy, and not lava)
static func _can_land(state: GameState, p: Piece, to: int) -> bool:
	if state.is_lava(to):
		return false
	var t: Piece = state.board[to]
	if t == null:
		return true
	return t.color != p.color and not state.is_shielded(t)


static func _step_moves(state: GameState, from: int, p: Piece, offsets: Array, out: Array) -> void:
	var f := Chess.file_of(from)
	var r := Chess.rank_of(from)
	for o in offsets:
		var nf: int = f + o[0]
		var nr: int = r + o[1]
		if Chess.on_board(nf, nr):
			var to := Chess.sq(nf, nr)
			if _can_land(state, p, to):
				out.append(GameAction.move(from, to))


static func _slide_moves(state: GameState, from: int, p: Piece, dirs: Array, out: Array) -> void:
	var f := Chess.file_of(from)
	var r := Chess.rank_of(from)
	for d in dirs:
		var nf: int = f + d[0]
		var nr: int = r + d[1]
		while Chess.on_board(nf, nr):
			var to := Chess.sq(nf, nr)
			if state.is_lava(to):
				break
			var t: Piece = state.board[to]
			if t == null:
				out.append(GameAction.move(from, to))
			else:
				if t.color != p.color and not state.is_shielded(t):
					out.append(GameAction.move(from, to))
				break
			nf += d[0]
			nr += d[1]


static func _add_pawn_move(from: int, to: int, color: int, out: Array) -> void:
	if Chess.rank_of(to) == Chess.promotion_rank(color):
		for k in [Chess.Kind.QUEEN, Chess.Kind.ROOK, Chess.Kind.BISHOP, Chess.Kind.KNIGHT]:
			out.append(GameAction.move(from, to, k))
	else:
		out.append(GameAction.move(from, to))


static func _pawn_moves(state: GameState, from: int, p: Piece, out: Array) -> void:
	var f := Chess.file_of(from)
	var r := Chess.rank_of(from)
	var dir := Chess.forward(p.color)
	var start_rank := 1 if p.color == Chess.WHITE else 6
	# Forward pushes
	if Chess.on_board(f, r + dir):
		var one := Chess.sq(f, r + dir)
		if state.board[one] == null and not state.is_lava(one):
			_add_pawn_move(from, one, p.color, out)
			if r == start_rank:
				var two := Chess.sq(f, r + 2 * dir)
				if state.board[two] == null and not state.is_lava(two):
					out.append(GameAction.move(from, two))
	# Captures (including en passant)
	for df in [-1, 1]:
		var nf: int = f + df
		var nr: int = r + dir
		if not Chess.on_board(nf, nr):
			continue
		var to := Chess.sq(nf, nr)
		if state.is_lava(to):
			continue
		var t: Piece = state.board[to]
		if t != null:
			if t.color != p.color and not state.is_shielded(t):
				_add_pawn_move(from, to, p.color, out)
		elif to == state.ep_square:
			var victim: Piece = state.board[Chess.sq(nf, r)]
			if victim != null and victim.kind == Chess.Kind.PAWN and victim.color != p.color \
					and not state.is_shielded(victim):
				out.append(GameAction.move(from, to))


static func _castle_moves(state: GameState, from: int, p: Piece, out: Array) -> void:
	var rank := 0 if p.color == Chess.WHITE else 7
	if p.has_moved or from != Chess.sq(4, rank):
		return
	var enemy := Chess.other(p.color)
	if is_attacked(state, from, enemy):
		return
	# King side: f and g must be empty; king passes f, lands on g.
	if state.can_castle(p.color, 7) and not state.is_frozen(state.board[Chess.sq(7, rank)]):
		if _castle_path_ok(state, rank, [5, 6], [5, 6], enemy):
			out.append(GameAction.move(from, Chess.sq(6, rank)))
	# Queen side: b, c, d must be empty; king passes d, lands on c.
	if state.can_castle(p.color, 0) and not state.is_frozen(state.board[Chess.sq(0, rank)]):
		if _castle_path_ok(state, rank, [1, 2, 3], [3, 2], enemy):
			out.append(GameAction.move(from, Chess.sq(2, rank)))


static func _castle_path_ok(state: GameState, rank: int, empty_files: Array, safe_files: Array, enemy: int) -> bool:
	for f in empty_files:
		var s := Chess.sq(f, rank)
		if state.board[s] != null or state.is_lava(s):
			return false
	for f in safe_files:
		if is_attacked(state, Chess.sq(f, rank), enemy):
			return false
	return true


## True if any piece of color `by` attacks square `s`.
## Lava blocks sliding attacks (it is a wall). Frozen pieces still attack.
static func is_attacked(state: GameState, s: int, by: int) -> bool:
	var f := Chess.file_of(s)
	var r := Chess.rank_of(s)
	# Pawns: a pawn of `by` attacks diagonally forward, so look "backwards" from s.
	var pr := r - Chess.forward(by)
	for df in [-1, 1]:
		if Chess.on_board(f + df, pr):
			var p: Piece = state.board[Chess.sq(f + df, pr)]
			if p != null and p.color == by and p.kind == Chess.Kind.PAWN:
				return true
	for o in Chess.KNIGHT_OFFSETS:
		if Chess.on_board(f + o[0], r + o[1]):
			var p: Piece = state.board[Chess.sq(f + o[0], r + o[1])]
			if p != null and p.color == by and p.kind == Chess.Kind.KNIGHT:
				return true
	for o in Chess.KING_OFFSETS:
		if Chess.on_board(f + o[0], r + o[1]):
			var p: Piece = state.board[Chess.sq(f + o[0], r + o[1])]
			if p != null and p.color == by and p.kind == Chess.Kind.KING:
				return true
	if _ray_attack(state, f, r, Chess.ROOK_DIRS, by, Chess.Kind.ROOK):
		return true
	if _ray_attack(state, f, r, Chess.BISHOP_DIRS, by, Chess.Kind.BISHOP):
		return true
	return false


static func _ray_attack(state: GameState, f: int, r: int, dirs: Array, by: int, slider: int) -> bool:
	for d in dirs:
		var nf: int = f + d[0]
		var nr: int = r + d[1]
		while Chess.on_board(nf, nr):
			var s := Chess.sq(nf, nr)
			if state.is_lava(s):
				break
			var p: Piece = state.board[s]
			if p != null:
				if p.color == by and (p.kind == slider or p.kind == Chess.Kind.QUEEN):
					return true
				break
			nf += d[0]
			nr += d[1]
	return false
