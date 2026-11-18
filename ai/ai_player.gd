class_name AiPlayer
extends RefCounted
## A computer opponent for the battlefield. Battles are chancy, so it looks at
## both outcomes of every attack and weighs them by the win chance ("expectimax").
## Levels: 0 = Squire (easy), 1 = Knight (medium), 2 = King (hard).

const WIN := 1000000
const KING_DANGER := 3000
const ENERGY_VALUE := 12
const INCOME_VALUE := 45

var rng := RandomNumberGenerator.new()


func choose_action(state: GameState, level: int) -> GameAction:
	var actions := Rules.legal_actions(state)
	if actions.is_empty():
		return null
	var noise := 70 if level <= 0 else (20 if level == 1 else 0)
	var scored := []
	for a in actions:
		scored.append([_expected(state, a, 0), a])
	if level >= 2:
		# Look one reply deeper for the most promising actions.
		scored.sort_custom(func(x, y): return x[0] > y[0])
		for i in mini(8, scored.size()):
			scored[i][0] = _expected(state, scored[i][1], 1)
	var best: GameAction = null
	var best_score := -INF
	for entry in scored:
		var sc: float = entry[0] + rng.randf_range(-noise, noise)
		if sc > best_score:
			best_score = sc
			best = entry[1]
	return best


## Value of doing `a`, from the point of view of the side doing it.
## depth = how many opponent replies to look at.
func _expected(state: GameState, a: GameAction, depth: int) -> float:
	if Rules.is_attack(state, a):
		var p := Combat.chance(state, a.from, a.to) / 100.0
		var win := state.clone()
		Rules.apply_action(win, a, Rules.Outcome.ATTACKER_WINS)
		var lose := state.clone()
		Rules.apply_action(lose, a, Rules.Outcome.DEFENDER_WINS)
		return p * -_value(win, depth) + (1.0 - p) * -_value(lose, depth)
	var c := state.clone()
	Rules.apply_action(c, a)
	return -_value(c, depth)


## Value of a position for the side to move.
func _value(state: GameState, depth: int) -> float:
	if state.winner >= 0:
		if state.winner == 2:
			return 0.0
		return WIN if state.winner == state.side_to_move else -WIN
	if depth <= 0:
		return evaluate(state)
	var best := -INF
	for a in Rules.legal_actions(state):
		best = maxf(best, _expected(state, a, depth - 1))
	return best


## Static score for the side to move: units, energy, miners, king safety and
## the best attack available right now.
func evaluate(state: GameState) -> float:
	var me := state.side_to_move
	var them := Chess.other(me)
	var score := 0.0
	var kings := [state.find_king(Chess.WHITE), state.find_king(Chess.BLACK)]
	for s in Chess.N:
		var p := state.piece_at(s)
		if p == null:
			continue
		var v := float(UnitData.value(p.kind))
		# Small bonus for moving forward and for standing on good terrain.
		var advance := Chess.rank_of(s) if p.color == Chess.WHITE else Chess.H - 1 - Chess.rank_of(s)
		if p.kind != Chess.Kind.KING and p.kind != Chess.Kind.MINER:
			v += advance * 7
			# Fighters are drawn toward the enemy king.
			var enemy_king: int = kings[Chess.other(p.color)]
			if enemy_king >= 0:
				v += (Chess.W - Chess.distance(s, enemy_king)) * 5
		match state.terrain_at(s):
			Chess.Terrain.HILL, Chess.Terrain.FOREST:
				v += 15
		score += v if p.color == me else -v
	score += (int(state.energy[me]) - int(state.energy[them])) * ENERGY_VALUE
	score += (state.income(me) - state.income(them)) * INCOME_VALUE
	# King danger: it is our move, so threats against their king count more.
	score += _king_threat(state, them, me) * KING_DANGER
	score -= _king_threat(state, me, them) * KING_DANGER * 0.6
	# The best attack we could make right now.
	var best_gain := 0.0
	for from in Chess.N:
		var p := state.piece_at(from)
		if p == null or p.color != me or state.is_frozen(p):
			continue
		for to in MoveGen.reachable(state, from):
			var d := state.piece_at(to)
			if d == null or d.kind == Chess.Kind.KING:
				continue
			var ch := Combat.chance(state, from, to) / 100.0
			var gain := ch * UnitData.value(d.kind) - (1.0 - ch) * UnitData.value(p.kind) * 0.5
			best_gain = maxf(best_gain, gain)
	return score + best_gain * 0.6


## Highest chance that `attacker_color` kills the king of `king_color` next move.
func _king_threat(state: GameState, king_color: int, attacker_color: int) -> float:
	var k := state.find_king(king_color)
	if k < 0:
		return 1.0
	var best := 0.0
	for from in MoveGen.attackers_of(state, k, attacker_color):
		best = maxf(best, Combat.chance(state, from, k) / 100.0)
	return best
