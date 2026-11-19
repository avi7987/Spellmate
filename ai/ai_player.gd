class_name AiPlayer
extends RefCounted
## The computer opponent for the big world. It works one action at a time:
## call choose_action() again and again until it returns END_TURN.
##
## Plan of a turn:
##   1. Recruit (miners first, then a mix of fighters) while energy allows.
##   2. For every unit, score each option - attack now, walk then attack,
##      use its power, or walk toward its goal - and do the best one.
## Goals: miners go to free crystal mines, fighters march on the enemy gate
## (or the king once the gate is down), and defenders return when the palace
## is threatened. Levels: 0 = Squire, 1 = Knight, 2 = King.
## (It sees through the fog of war - a simplification for now.)

const KILL_BONUS := 1.6
const KING_TARGET := 20000.0

var rng := RandomNumberGenerator.new()
## Enemy units this decision: [[square, reach, attack], ...] (computed once per call).
var _threats: Array = []


func choose_action(state: GameState, level: int) -> GameAction:
	if state.winner >= 0:
		return GameAction.end_turn()
	var me := state.side_to_move
	var rec := _recruit(state, level)
	if rec != null:
		return rec
	_threats.clear()
	for s in state.units_of(Chess.other(me)):
		var u := state.piece_at(s)
		_threats.append([s, UnitData.move_points(u.kind) + UnitData.attack_range(u.kind), UnitData.attack(u.kind)])
	var best: GameAction = null
	var best_score := 0.5
	var noise := 40.0 if level <= 0 else (12.0 if level == 1 else 0.0)
	for s in state.units_of(me):
		var p := state.piece_at(s)
		if p.acted or state.is_frozen(p):
			continue
		for opt in _options(state, s, level):
			var sc: float = opt[0] + rng.randf_range(-noise, noise)
			if sc > best_score:
				best_score = sc
				best = opt[1]
	return best if best != null else GameAction.end_turn()


# ------------------------------------------------------------ recruiting

func _recruit(state: GameState, level: int) -> GameAction:
	var me := state.side_to_move
	var energy := int(state.energy[me])
	var spots := Rules.spawn_squares(state, me)
	if spots.is_empty():
		return null
	# Keep a little energy for powers on higher levels.
	var reserve := 0 if level <= 0 else 2
	var want := -1
	var miners := state.count(me, Chess.Kind.MINER)
	if miners < 3:
		want = Chess.Kind.MINER
	else:
		var army := state.units_of(me).size()
		if army >= 14 + level * 3:
			return null
		var picks := [Chess.Kind.PAWN, Chess.Kind.ARCHER, Chess.Kind.KNIGHT, Chess.Kind.SHIELD,
			Chess.Kind.HEALER, Chess.Kind.FIRE_MAGE, Chess.Kind.ICE_WITCH, Chess.Kind.ASSASSIN,
			Chess.Kind.GIANT, Chess.Kind.BALLISTA, Chess.Kind.DRAGON]
		# Save up for big units sometimes; otherwise take the best we can pay for.
		var affordable := picks.filter(func(k): return UnitData.cost(k) <= energy - reserve)
		if affordable.is_empty():
			return null
		affordable.shuffle()
		affordable.sort_custom(func(a, b): return UnitData.cost(a) > UnitData.cost(b))
		want = affordable[mini(rng.randi_range(0, 2), affordable.size() - 1)]
	if want < 0 or UnitData.cost(want) > energy:
		return null
	return GameAction.recruit(want, _best_spot(state, spots, me))


func _best_spot(state: GameState, spots: Array, me: int) -> int:
	var goal := _enemy_goal(state, me)
	var best: int = spots[0]
	for s in spots:
		if Chess.distance(s, goal) < Chess.distance(best, goal):
			best = s
	return best


# ------------------------------------------------------------ options

## [[score, action], ...] for one unit.
func _options(state: GameState, from: int, level: int) -> Array:
	var p := state.piece_at(from)
	var out := []
	# Attack from where it stands.
	for t in MoveGen.attack_targets(state, from):
		out.append([_attack_score(state, from, from, t), GameAction.attack(from, t)])
	# Powers.
	var ab := AbilityRegistry.for_kind(p.kind)
	if state.abilities_enabled and ab != null and ab.can_activate(state, from):
		for t in ab.targets(state, from):
			out.append([_power_score(state, ab.id, from, t), GameAction.ability(ab.id, from, t)])
	if p.moved or p.kind == Chess.Kind.KING:
		return out
	# Walk somewhere (maybe to attack next).
	var goal := _goal_for(state, from)
	var here_d := _goal_distance(from, goal)
	for to in MoveGen.reachable(state, from):
		var sc := 0.0
		var hits := MoveGen.targets_from(state, from, to)
		var art := UnitData.trait_id(p.kind) == "artillery"
		if not hits.is_empty() and not art:
			var best_hit := 0.0
			for t in hits:
				best_hit = maxf(best_hit, _attack_score(state, from, to, t))
			sc += best_hit * 0.9
		sc += (here_d - _goal_distance(to, goal)) * 10.0
		if p.kind == Chess.Kind.MINER and state.terrain_at(to) == Chess.Terrain.MINE:
			sc += 80.0
		match state.terrain_at(to):
			Chess.Terrain.FOREST, Chess.Terrain.HILL:
				sc += 4.0
		# Fragile units fear danger; sturdy ones march on.
		var caution := 0.35 if p.max_hp < 15 else 0.08
		if state.ply > 100:
			caution *= 0.3   # late in the war: all-out attack
		sc -= _danger(state, to, p) * caution * (1.0 if level >= 1 else 0.5)
		if sc > 0.0:
			out.append([sc, GameAction.move(from, to)])
	return out


func _attack_score(state: GameState, from: int, at: int, target: int) -> float:
	var a := state.piece_at(from)
	var d := state.piece_at(target)
	var dmg := float(Combat.base_damage(state, a, at, target))
	if d == null:
		var st := state.structure_at(target)
		var worth := 600.0 if st["kind"] == "gate" else 260.0
		return worth * minf(1.0, dmg / maxf(1.0, float(st["hp"]))) + dmg * 4.0
	var val := float(UnitData.value(d.kind))
	if d.kind == Chess.Kind.KING:
		val = KING_TARGET
	var frac := minf(1.0, dmg / float(d.hp))
	var sc := val * frac * (KILL_BONUS if dmg >= d.hp else 0.6)
	if dmg < d.hp and Combat.can_counter(state, d, target, at):
		var back := Combat.base_damage(state, d, target, at) * Balance.combat("counter_factor") / 100.0
		sc -= UnitData.value(a.kind) * minf(1.0, back / float(a.hp)) * 0.7
	return sc


func _power_score(state: GameState, id: String, from: int, target: int) -> float:
	var me := state.side_to_move
	match id:
		"heal":
			var t := state.piece_at(target)
			return float(t.max_hp - t.hp) * 12.0 if t.max_hp - t.hp >= 4 else 0.0
		"frost", "fire_breath":
			var n := 0.0
			for s in [target] + Ability.neighbors(target, Chess.KING_OFFSETS):
				var u := state.piece_at(s)
				if u != null and u.color != me:
					n += UnitData.value(u.kind) * 0.35
			return n
		"brace", "royal_decree":
			return 40.0 if _danger(state, from, state.piece_at(from)) > 0.0 else 0.0
		"toil":
			return 25.0 if state.terrain_at(from) != Chess.Terrain.MINE and _nearest_free_mine(state, from) < 0 else 0.0
	return 0.0


## How much enemy attack power could reach this square next turn.
func _danger(_state: GameState, s: int, p: Piece) -> float:
	var total := 0.0
	for t in _threats:
		if Chess.distance(t[0], s) <= t[1]:
			total += t[2]
	return total * 4.0 * (1.5 if UnitData.attack_range(p.kind) > 1 else 1.0)


# ------------------------------------------------------------ goals

func _enemy_goal(state: GameState, me: int) -> int:
	var gate := state.gate_of(Chess.other(me))
	if not gate.is_empty():
		return int(gate["square"])
	var k := state.find_king(Chess.other(me))
	return k if k >= 0 else Chess.sq(Chess.W / 2, Chess.H / 2)


func _goal_for(state: GameState, from: int) -> int:
	var p := state.piece_at(from)
	if p.kind == Chess.Kind.MINER:
		var m := _nearest_free_mine(state, from)
		return m if m >= 0 else from
	if p.kind == Chess.Kind.HEALER:
		# Stay with the army: head for the closest friend that is hurt.
		var best := -1
		for s in state.units_of(p.color):
			var u := state.piece_at(s)
			if s != from and u.hp < u.max_hp and (best < 0 or Chess.distance(from, s) < Chess.distance(from, best)):
				best = s
		if best >= 0:
			return best
	# Defend the palace when enemies are close to it.
	var gate := state.gate_of(p.color)
	if not gate.is_empty():
		for s in state.units_of(Chess.other(p.color)):
			if Chess.distance(s, int(gate["square"])) <= 6 and Chess.distance(from, int(gate["square"])) <= 10:
				return s
	return _enemy_goal(state, p.color)


func _goal_distance(a: int, b: int) -> float:
	return float(Chess.distance(a, b))


func _nearest_free_mine(state: GameState, from: int) -> int:
	var best := -1
	for s in Chess.N:
		if state.terrain_at(s) != Chess.Terrain.MINE:
			continue
		var occ := state.piece_at(s)
		if occ != null and s != from:
			continue
		if best < 0 or Chess.distance(from, s) < Chess.distance(from, best):
			best = s
	return best
