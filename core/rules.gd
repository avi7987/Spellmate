class_name Rules
extends RefCounted
## The referee. Lists legal actions, applies them (fights included), runs the
## start of each turn (energy, towers, fire) and decides when the war is over.
## Every change to a GameState goes through apply_action().
##
## A turn: every unit may move once and then attack or use its power once.
## New units can be recruited at the palace gate for energy. Then END_TURN.
## Win by killing the enemy king inside his palace.

enum Result { ONGOING, WHITE_WINS, BLACK_WINS, DRAW }
## The AI uses AVERAGE to plan without luck.
enum Outcome { RANDOM, AVERAGE }


# ------------------------------------------------------------ legal actions

## Everything the unit on `from` can do now (moves, attacks, powers).
static func legal_actions_from(state: GameState, from: int) -> Array:
	var out := []
	var p := state.piece_at(from)
	if p == null or p.color != state.side_to_move or state.winner >= 0:
		return out
	for s in MoveGen.reachable(state, from):
		out.append(GameAction.move(from, s))
	for t in MoveGen.attack_targets(state, from):
		out.append(GameAction.attack(from, t))
	if state.abilities_enabled and not p.acted:
		var ab := AbilityRegistry.for_kind(p.kind)
		if ab != null and ab.can_activate(state, from):
			for t in ab.targets(state, from):
				out.append(GameAction.ability(ab.id, from, t))
	return out


## All legal actions for the side to move (including recruiting and ending the turn).
static func legal_actions(state: GameState) -> Array:
	var out := []
	if state.winner >= 0:
		return out
	for s in state.units_of(state.side_to_move):
		out.append_array(legal_actions_from(state, s))
	out.append_array(recruit_actions(state))
	out.append(GameAction.end_turn())
	return out


## Free squares around the gate where new units appear.
static func spawn_squares(state: GameState, color: int) -> Array:
	var gate := state.gate_of(color)
	var out := []
	var center: int = int(gate["square"]) if not gate.is_empty() else state.find_king(color)
	if center < 0:
		return out
	for o in Chess.KING_OFFSETS + [[0, 0]]:
		var f: int = Chess.file_of(center) + o[0]
		var r: int = Chess.rank_of(center) + o[1]
		if not Chess.on_board(f, r):
			continue
		var s := Chess.sq(f, r)
		var t := state.terrain[s]
		if state.piece_at(s) == null and t != Chess.Terrain.WATER and t != Chess.Terrain.WALL and not state.is_lava(s):
			out.append(s)
	return out


static func recruit_actions(state: GameState) -> Array:
	var out := []
	var me := state.side_to_move
	var spots := spawn_squares(state, me)
	if spots.is_empty():
		return out
	for k in UnitData.recruitable():
		if int(state.energy[me]) >= UnitData.cost(k):
			out.append(GameAction.recruit(k, spots[0]))
	return out


static func is_legal(state: GameState, action: GameAction) -> bool:
	match action.type:
		GameAction.Type.END_TURN:
			return state.winner < 0
		GameAction.Type.RECRUIT:
			return state.winner < 0 and int(state.energy[state.side_to_move]) >= UnitData.cost(action.kind) \
				and UnitData.cost(action.kind) > 0 and spawn_squares(state, state.side_to_move).has(action.to)
	for a in legal_actions_from(state, action.from):
		if a.equals(action):
			return true
	return false


# ------------------------------------------------------------ applying

## Applies an action (assumed legal) and returns events describing what
## happened, for animations and sound. Events are plain Dictionaries.
static func apply_action(state: GameState, action: GameAction, outcome: int = Outcome.RANDOM) -> Array:
	var events := []
	var me := state.side_to_move
	match action.type:
		GameAction.Type.MOVE:
			var p := state.piece_at(action.from)
			var route := MoveGen.path(state, action.from, action.to)
			var steps: int = MoveGen.reachable(state, action.from).get(action.to, 1)
			state.board[action.to] = p
			state.board[action.from] = null
			p.moved = true
			p.has_moved = true
			p.steps_taken = steps
			events.append({ "type": "move", "piece_id": p.id, "from": action.from, "to": action.to, "path": route })
		GameAction.Type.ATTACK:
			_attack(state, action.from, action.to, outcome, events)
		GameAction.Type.ABILITY:
			var ab := AbilityRegistry.by_id(action.ability_id)
			var caster := state.piece_at(action.from)
			state.energy[me] = int(state.energy[me]) - ab.cost
			caster.ability_ready_ply = state.ply + ab.cooldown * 2
			caster.acted = true
			caster.moved = true
			events.append({ "type": "ability", "ability_id": ab.id, "piece_id": caster.id,
				"from": action.from, "target": action.to })
			ab.apply(state, action.from, action.to, events)
		GameAction.Type.RECRUIT:
			state.energy[me] = int(state.energy[me]) - UnitData.cost(action.kind)
			var u := state.add_piece(action.kind, me, action.to)
			u.moved = true
			u.acted = true
			events.append({ "type": "recruit", "piece_id": u.id, "kind": u.kind, "square": action.to, "color": me })
		GameAction.Type.END_TURN:
			_end_turn(state, events)
	state.update_explored()
	return events


## A unit attacks a unit, gate or tower. The defender may hit back.
static func _attack(state: GameState, from: int, to: int, outcome: int, events: Array) -> void:
	var a := state.piece_at(from)
	var d := state.piece_at(to)
	a.acted = true
	a.moved = true
	var raw := Combat.base_damage(state, a, from, to)
	var dmg := raw if outcome == Outcome.AVERAGE else Combat.roll(state, raw)
	var ev := { "type": "attack", "attacker_id": a.id, "attacker_kind": a.kind, "attacker_color": a.color,
		"from": from, "to": to, "damage": dmg, "counter": 0, "ranged": Chess.distance(from, to) > 1 }
	if d != null:
		ev["defender_id"] = d.id
		ev["defender_kind"] = d.kind
		ev["defender_hp_before"] = d.hp
		ev["attacker_hp_before"] = a.hp
		d.hp -= dmg
		ev["defender_hp"] = maxi(0, d.hp)
		if d.hp > 0 and Combat.can_counter(state, d, to, from):
			var craw := maxi(1, roundi(Combat.base_damage(state, d, to, from) * Balance.combat("counter_factor") / 100.0))
			var cdmg := craw if outcome == Outcome.AVERAGE else Combat.roll(state, craw)
			a.hp -= cdmg
			ev["counter"] = cdmg
		ev["attacker_hp"] = maxi(0, a.hp)
		# The ice witch's touch slows; the fire mage's blast splashes.
		match UnitData.trait_id(a.kind):
			"chill":
				if d.hp > 0:
					state.slows[d.id] = state.ply + 3
					ev["slowed"] = true
			"blast":
				ev["splash"] = []
				for o in Chess.KING_OFFSETS:
					var f: int = Chess.file_of(to) + o[0]
					var r: int = Chess.rank_of(to) + o[1]
					if not Chess.on_board(f, r):
						continue
					var n := state.piece_at(Chess.sq(f, r))
					if n != null and n.color != a.color:
						var sd := maxi(1, roundi(dmg * Balance.combat("blast_splash") / 100.0))
						n.hp -= sd
						ev["splash"].append({ "piece_id": n.id, "square": Chess.sq(f, r), "damage": sd })
		events.append(ev)
		_bury(state, events)
	else:
		var st := state.structure_at(to)
		ev["structure_id"] = st["id"]
		ev["structure_kind"] = st["kind"]
		ev["defender_hp_before"] = st["hp"]
		st["hp"] = int(st["hp"]) - dmg
		ev["defender_hp"] = maxi(0, int(st["hp"]))
		ev["attacker_hp_before"] = a.hp
		ev["attacker_hp"] = a.hp
		events.append(ev)
		if int(st["hp"]) <= 0:
			_destroy_structure(state, st, events)


## Removes every unit at 0 health (and ends the war if a king fell).
static func _bury(state: GameState, events: Array) -> void:
	for s in Chess.N:
		var p := state.piece_at(s)
		if p != null and p.hp <= 0:
			state.board[s] = null
			events.append({ "type": "death", "piece_id": p.id, "kind": p.kind, "square": s, "color": p.color })
			if p.kind == Chess.Kind.KING and state.winner < 0:
				state.winner = Chess.other(p.color)


static func _destroy_structure(state: GameState, st: Dictionary, events: Array) -> void:
	state.structures.erase(st)
	var s: int = st["square"]
	if st["kind"] == "tower":
		state.terrain[s] = Chess.Terrain.PLAIN   # a breach in the wall
	events.append({ "type": "destroyed", "structure_id": st["id"], "kind": st["kind"], "square": s, "color": st["color"] })


## Switches sides and runs the start of the next turn: energy from miners,
## fire burns, palace towers shoot at nearby enemies.
static func _end_turn(state: GameState, events: Array) -> void:
	var me := state.side_to_move
	state.ply += 1
	state.side_to_move = Chess.other(me)
	var them := state.side_to_move
	state.purge_expired()
	events.append({ "type": "turn", "color": them })
	if state.winner < 0 and state.ply >= Balance.turn_limit():
		state.winner = 2
		return
	for s in state.units_of(them):
		var p := state.piece_at(s)
		p.moved = false
		p.acted = false
		p.steps_taken = 0
	# Fire hurts whoever stands in it.
	for s in Chess.N:
		var p := state.piece_at(s)
		if p != null and state.is_lava(s):
			var fd := int(Balance.ability("fire_breath").get("damage", 4))
			p.hp -= fd
			events.append({ "type": "burn", "piece_id": p.id, "square": s, "damage": fd })
	# Palace towers shoot the nearest enemy in range.
	for st in state.structures.duplicate():
		if st["kind"] != "tower" or int(st["color"]) != them:
			continue
		var data := UnitData.structure("tower")
		var best := -1
		for s in Chess.N:
			var p := state.piece_at(s)
			if p != null and p.color != them and Chess.distance(s, int(st["square"])) <= int(data.get("range", 3)):
				if best < 0 or Chess.distance(s, int(st["square"])) < Chess.distance(best, int(st["square"])):
					best = s
		if best >= 0:
			var victim := state.piece_at(best)
			var dmg := maxi(1, Combat.roll(state, int(data.get("atk", 4)) - UnitData.armor(victim.kind)))
			victim.hp -= dmg
			events.append({ "type": "tower_shot", "structure_id": st["id"], "from": st["square"], "to": best,
				"piece_id": victim.id, "damage": dmg })
	_bury(state, events)
	var before := int(state.energy[them])
	state.add_energy(them, state.income(them))
	var gained := int(state.energy[them]) - before
	if gained > 0:
		events.append({ "type": "energy", "color": them, "amount": gained })


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
