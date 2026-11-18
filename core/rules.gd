class_name Rules
extends RefCounted
## The referee. Lists legal actions, applies them (including battles), and
## decides when the war is over. Every change to a GameState goes through
## apply_action().
##
## A turn = ONE action: move a unit (moving onto an enemy starts a battle),
## or use a unit's power. Win by killing the enemy king.

enum Result { ONGOING, WHITE_WINS, BLACK_WINS, DRAW }
## Force the dice in apply_action (used by the AI to look at both outcomes).
enum Outcome { RANDOM, ATTACKER_WINS, DEFENDER_WINS }


# ------------------------------------------------------------ legal actions

## All legal actions for the side to move. If a side cannot do anything, it passes.
static func legal_actions(state: GameState) -> Array:
	if state.winner >= 0:
		return []
	var out := legal_moves(state)
	out.append_array(legal_abilities(state))
	if out.is_empty():
		out.append(GameAction.pass_turn())
	return out


static func legal_moves(state: GameState) -> Array:
	var out := []
	MoveGen.pseudo_moves(state, out)
	return out


static func legal_abilities(state: GameState) -> Array:
	var out := []
	if not state.abilities_enabled:
		return out
	for s in Chess.N:
		var p := state.piece_at(s)
		if p != null and p.color == state.side_to_move:
			_ability_actions(state, s, out)
	return out


## Legal actions that start from one square (used when a unit is selected).
static func legal_actions_from(state: GameState, from: int) -> Array:
	var out := []
	var p := state.piece_at(from)
	if p == null or p.color != state.side_to_move or state.winner >= 0:
		return out
	MoveGen.piece_moves(state, from, out)
	if state.abilities_enabled:
		_ability_actions(state, from, out)
	return out


static func _ability_actions(state: GameState, from: int, out: Array) -> void:
	var p := state.piece_at(from)
	var ab := AbilityRegistry.for_kind(p.kind)
	if ab == null or not ab.can_activate(state, from):
		return
	for t in ab.targets(state, from):
		out.append(GameAction.ability(ab.id, from, t))


static func is_legal(state: GameState, action: GameAction) -> bool:
	if action.type == GameAction.Type.PASS:
		return legal_actions(state).any(func(a): return a.type == GameAction.Type.PASS)
	for a in legal_actions_from(state, action.from):
		if a.equals(action):
			return true
	return false


## Is this move an attack (does it start a battle)?
static func is_attack(state: GameState, action: GameAction) -> bool:
	return action.type == GameAction.Type.MOVE and state.piece_at(action.to) != null


# ------------------------------------------------------------ applying

## Applies an action (assumed legal) and returns a list of events describing
## what happened, for animations and sound. Events are plain Dictionaries.
static func apply_action(state: GameState, action: GameAction, outcome: int = Outcome.RANDOM) -> Array:
	var events := []
	var mover := state.side_to_move
	match action.type:
		GameAction.Type.MOVE:
			if is_attack(state, action):
				_battle(state, action, outcome, events)
			else:
				_move(state, action.from, action.to, events)
		GameAction.Type.ABILITY:
			var ab := AbilityRegistry.by_id(action.ability_id)
			var caster := state.piece_at(action.from)
			state.energy[mover] = int(state.energy[mover]) - ab.cost
			caster.ability_ready_ply = state.ply + ab.cooldown * 2
			events.append({ "type": "ability", "ability_id": ab.id, "piece_id": caster.id,
				"from": action.from, "target": action.to })
			ab.apply(state, action.from, action.to, events)
		GameAction.Type.PASS:
			events.append({ "type": "pass" })
	# --- end of turn
	state.ply += 1
	state.side_to_move = Chess.other(mover)
	state.purge_expired()
	if state.winner < 0 and state.ply >= Balance.turn_limit():
		state.winner = 2
	if state.winner < 0:
		var before := int(state.energy[state.side_to_move])
		state.gain_turn_energy()
		var gained := int(state.energy[state.side_to_move]) - before
		if gained > 0:
			events.append({ "type": "energy", "color": state.side_to_move, "amount": gained })
	return events


static func _move(state: GameState, from: int, to: int, events: Array) -> void:
	var p := state.piece_at(from)
	state.board[to] = p
	state.board[from] = null
	p.has_moved = true
	events.append({ "type": "move", "piece_id": p.id, "from": from, "to": to })


static func _battle(state: GameState, a: GameAction, outcome: int, events: Array) -> void:
	var attacker := state.piece_at(a.from)
	var defender := state.piece_at(a.to)
	var chance := Combat.chance(state, a.from, a.to)
	var roll := state.roll_d100()
	var won := roll < chance
	if outcome == Outcome.ATTACKER_WINS:
		won = true
	elif outcome == Outcome.DEFENDER_WINS:
		won = false
	var loser := defender if won else attacker
	var survives := not won and UnitData.trait_id(attacker.kind) == "phase"
	events.append({ "type": "battle", "attacker_id": attacker.id, "defender_id": defender.id,
		"attacker_kind": attacker.kind, "defender_kind": defender.kind,
		"from": a.from, "to": a.to, "chance": chance, "roll": roll, "won": won, "phased": survives })
	if won:
		state.board[a.to] = null
		_move(state, a.from, a.to, events)
	elif not survives:
		state.board[a.from] = null
	if not survives:
		events.append({ "type": "death", "piece_id": loser.id, "kind": loser.kind,
			"square": a.to if won else a.from })
		if loser.kind == Chess.Kind.KING:
			state.winner = Chess.other(loser.color)


# ------------------------------------------------------------ game end

## Returns { "result": Result, "reason": String }. reasons: "king", "turns", ""
static func game_result(state: GameState) -> Dictionary:
	match state.winner:
		Chess.WHITE:
			return { "result": Result.WHITE_WINS, "reason": "king" }
		Chess.BLACK:
			return { "result": Result.BLACK_WINS, "reason": "king" }
		2:
			return { "result": Result.DRAW, "reason": "turns" }
	return { "result": Result.ONGOING, "reason": "" }
