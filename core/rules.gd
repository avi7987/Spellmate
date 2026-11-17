class_name Rules
extends RefCounted
## The referee. Lists legal actions, applies them, and decides when the game ends.
## Every change to a GameState goes through apply_action().

enum Result { ONGOING, WHITE_WINS, BLACK_WINS, DRAW }


# ------------------------------------------------------------ legal actions

## All legal actions (moves + abilities) for the side to move.
static func legal_actions(state: GameState) -> Array:
	var out := legal_moves(state)
	out.append_array(legal_abilities(state))
	return out


static func legal_moves(state: GameState) -> Array:
	var pseudo := []
	MoveGen.pseudo_moves(state, pseudo)
	return _filter_legal(state, pseudo)


static func legal_abilities(state: GameState) -> Array:
	if not abilities_allowed(state):
		return []
	var pseudo := []
	for s in 64:
		var p := state.piece_at(s)
		if p != null and p.color == state.side_to_move:
			_ability_actions(state, s, pseudo)
	return _filter_legal(state, pseudo)


## Legal actions that start from one square (used by the UI when a piece is selected).
static func legal_actions_from(state: GameState, from: int) -> Array:
	var pseudo := []
	MoveGen.piece_moves(state, from, pseudo)
	if abilities_allowed(state):
		_ability_actions(state, from, pseudo)
	return _filter_legal(state, pseudo)


## Powers are off in classic mode, and a king in check must be answered with a
## normal chess move - so checkmate works exactly like in real chess.
static func abilities_allowed(state: GameState) -> bool:
	return state.abilities_enabled and not in_check(state, state.side_to_move)


static func _ability_actions(state: GameState, from: int, out: Array) -> void:
	var p := state.piece_at(from)
	var ab := AbilityRegistry.for_kind(p.kind)
	if ab == null or not ab.can_activate(state, from):
		return
	for t in ab.targets(state, from):
		out.append(GameAction.ability(ab.id, from, t))


## Keeps only actions that do not leave the mover's own king attacked.
static func _filter_legal(state: GameState, actions: Array) -> Array:
	var out := []
	var me := state.side_to_move
	for a in actions:
		var c := state.clone(false)
		apply_action(c, a)
		var k := c.find_king(me)
		if k >= 0 and not MoveGen.is_attacked(c, k, Chess.other(me)):
			out.append(a)
	return out


static func is_legal(state: GameState, action: GameAction) -> bool:
	for a in legal_actions_from(state, action.from):
		if a.equals(action):
			return true
	return false


static func in_check(state: GameState, color: int) -> bool:
	var k := state.find_king(color)
	return k >= 0 and MoveGen.is_attacked(state, k, Chess.other(color))


# ------------------------------------------------------------ applying

## Applies an action (assumed legal) and returns a list of events describing
## what happened, for animations and sound. Events are plain Dictionaries.
static func apply_action(state: GameState, action: GameAction) -> Array:
	var events := []
	var mover := state.side_to_move
	var reset_clock := false
	if action.type == GameAction.Type.MOVE:
		reset_clock = _apply_move(state, action, events)
	else:
		var ab := AbilityRegistry.by_id(action.ability_id)
		var caster := state.piece_at(action.from)
		state.energy[mover] = int(state.energy[mover]) - ab.cost
		caster.ability_ready_ply = state.ply + ab.cooldown * 2
		events.append({ "type": "ability", "ability_id": ab.id, "piece_id": caster.id,
			"from": action.from, "target": action.to })
		ab.apply(state, action.from, action.to, events)
		state.ep_square = -1
		reset_clock = caster.kind == Chess.Kind.PAWN
	# --- end of turn bookkeeping
	state.halfmove_clock = 0 if reset_clock else state.halfmove_clock + 1
	if mover == Chess.BLACK:
		state.fullmove_number += 1
	state.ply += 1
	state.side_to_move = Chess.other(mover)
	state.purge_expired()
	if state.abilities_enabled:
		state.gain_turn_energy()
	if state.track_history:
		state.history_keys.append(state.position_key())
	return events


## Returns true if the move resets the 50-move clock (pawn move or capture).
static func _apply_move(state: GameState, a: GameAction, events: Array) -> bool:
	var p := state.piece_at(a.from)
	var captured := state.piece_at(a.to)
	var capture_sq := a.to
	var resets := p.kind == Chess.Kind.PAWN
	# En passant: the captured pawn is beside us, not on the destination.
	if p.kind == Chess.Kind.PAWN and a.to == state.ep_square and captured == null \
			and Chess.file_of(a.from) != Chess.file_of(a.to):
		capture_sq = Chess.sq(Chess.file_of(a.to), Chess.rank_of(a.from))
		captured = state.piece_at(capture_sq)
	if captured != null:
		state.board[capture_sq] = null
		resets = true
		if state.abilities_enabled:
			state.add_energy(p.color, Balance.energy_per_capture())
		events.append({ "type": "capture", "piece_id": captured.id, "kind": captured.kind,
			"square": capture_sq, "by_id": p.id, "by_kind": p.kind })
	state.board[a.to] = p
	state.board[a.from] = null
	p.has_moved = true
	events.append({ "type": "move", "piece_id": p.id, "from": a.from, "to": a.to })
	# Castling: move the rook too.
	if p.kind == Chess.Kind.KING and absi(Chess.file_of(a.to) - Chess.file_of(a.from)) == 2:
		var rank := Chess.rank_of(a.from)
		var kingside := Chess.file_of(a.to) == 6
		var rook_from := Chess.sq(7 if kingside else 0, rank)
		var rook_to := Chess.sq(5 if kingside else 3, rank)
		var rook := state.piece_at(rook_from)
		state.board[rook_to] = rook
		state.board[rook_from] = null
		rook.has_moved = true
		events.append({ "type": "move", "piece_id": rook.id, "from": rook_from, "to": rook_to })
	# Promotion
	if a.promotion != 0:
		p.kind = a.promotion
		events.append({ "type": "promote", "piece_id": p.id, "square": a.to, "kind": a.promotion })
	# En passant square for the next player
	state.ep_square = -1
	if p.kind == Chess.Kind.PAWN and absi(a.to - a.from) == 16:
		state.ep_square = (a.from + a.to) >> 1
	return resets


# ------------------------------------------------------------ game end

## Returns { "result": Result, "reason": String }.
## reasons: "checkmate", "stalemate", "fifty_moves", "repetition", "material", ""
static func game_result(state: GameState) -> Dictionary:
	var me := state.side_to_move
	if legal_actions(state).is_empty():
		if in_check(state, me):
			return { "result": Result.BLACK_WINS if me == Chess.WHITE else Result.WHITE_WINS, "reason": "checkmate" }
		return { "result": Result.DRAW, "reason": "stalemate" }
	if state.halfmove_clock >= 100:
		return { "result": Result.DRAW, "reason": "fifty_moves" }
	if state.track_history and not state.history_keys.is_empty() \
			and state.history_keys.count(state.history_keys[-1]) >= 3:
		return { "result": Result.DRAW, "reason": "repetition" }
	if _insufficient_material(state):
		return { "result": Result.DRAW, "reason": "material" }
	return { "result": Result.ONGOING, "reason": "" }


static func _insufficient_material(state: GameState) -> bool:
	var minors := 0
	for p in state.all_pieces():
		match p.kind:
			Chess.Kind.KING:
				pass
			Chess.Kind.KNIGHT, Chess.Kind.BISHOP:
				minors += 1
			_:
				return false
	return minors <= 1


# ------------------------------------------------------------ testing

## Counts leaf nodes of the move tree (standard chess test, abilities off).
static func perft(state: GameState, depth: int) -> int:
	if depth == 0:
		return 1
	var moves := legal_moves(state)
	if depth == 1:
		return moves.size()
	var total := 0
	for m in moves:
		var c := state.clone(false)
		apply_action(c, m)
		total += perft(c, depth - 1)
	return total
