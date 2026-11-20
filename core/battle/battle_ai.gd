class_name BattleAI
extends RefCounted
## The computer opponent for real-time battles. think() is called about once a
## second: it summons heroes, sends the army, uses powers and spells.
## level 1 = easy (slow, wasteful), 2 = normal, 3 = hard.

var team := 1
var level := 2
var _next_think := 0.0
var _attacking := false
var _rng := RandomNumberGenerator.new()


func _init(t: int = 1, lvl: int = 2) -> void:
	team = t
	level = lvl
	_rng.seed = 1234 + t


func think(b: Battle) -> void:
	if b.is_over() or b.time < _next_think:
		return
	_next_think = b.time + (3.0 if level <= 0 else [1.6, 1.1, 0.7][clampi(level - 1, 0, 2)])
	_summon(b)
	if level <= 0:
		_army(b)
		return
	_spells(b)
	_powers(b)
	_army(b)
	if b.energy[team] >= 16.0 and b.palace_upgrade_cost(team) > 0:
		b.upgrade_palace(team)


## Simultaneous turns: the computer decides everything for the coming turn
## at once (summons, spells, powers, army orders), without seeing the
## player's plan.
func plan_turn(b: Battle) -> void:
	if b.is_over():
		return
	for i in (1 if level <= 0 else 3):
		_summon(b)
	if level > 0:
		_spells(b)
		_powers(b)
	_army(b)
	if level > 0 and b.energy[team] >= 16.0 and b.palace_upgrade_cost(team) > 0:
		b.upgrade_palace(team)


func _summon(b: Battle) -> void:
	var miners := b.units.filter(func(u): return u.team == team and u.role() == "miner").size()
	var options := []
	for i in b.cards[team].size():
		var id: String = b.cards[team][i]["id"]
		if BattleData.is_spell(id) or b.card_wait(team, i) != 0.0:
			continue
		if b.energy[team] < b.card_cost(id):
			continue
		var want := b.card_cost(id) + _rng.randf() * 3.0
		if BattleData.hero(id).get("role", "") == "miner":
			want = 20.0 if miners < 3 else -1.0
		options.append([want, i])
	if options.is_empty():
		return
	options.sort_custom(func(a, c): return a[0] > c[0])
	if options[0][0] < 0:
		return
	# keep a little energy for powers on higher levels
	var id: String = b.cards[team][options[0][1]]["id"]
	if level >= 2 and b.energy[team] - b.card_cost(id) < 1.0 and miners >= 2 and _rng.randf() < 0.5:
		return
	b.play_card(team, options[0][1])


func _enemy_clusters(b: Battle) -> Array:
	## Returns [pos, count, value] of the best enemy group for a bomb.
	var best := [Vector2.ZERO, 0, 0.0]
	for e: BUnit in b.units:
		if e.team == team or e.structure or e.kind == "king":
			continue
		var n := 0
		var v := 0.0
		for o: BUnit in b.units:
			if o.team != team and not o.structure and o.kind != "king" and o.pos.distance_to(e.pos) <= 1.8:
				n += 1
				v += b.card_cost(o.kind) + 1.0
		if v > best[2]:
			best = [e.pos, n, v]
	return best


func _spells(b: Battle) -> void:
	if level == 1 and _rng.randf() < 0.5:
		return
	var cluster := _enemy_clusters(b)
	var my_king := b.king(team)
	for i in b.cards[team].size():
		var id: String = b.cards[team][i]["id"]
		if not BattleData.is_spell(id) or b.card_wait(team, i) != 0.0 or b.energy[team] < b.card_cost(id):
			continue
		var sp := BattleData.spell(id)
		match sp["type"]:
			"area_damage":
				if cluster[1] >= 2 or (cluster[1] >= 1 and (level >= 2 or (my_king and cluster[0].distance_to(my_king.pos) < 6.0))):
					b.play_card(team, i, cluster[0])
					return
			"area_heal":
				var hurt := _hurt_group(b)
				if hurt[1] >= 2:
					b.play_card(team, i, hurt[0])
					return
			"wall":
				var gate := _my_gate(b)
				if gate and cluster[1] >= 2 and cluster[0].distance_to(gate.pos) < 5.0:
					var p: Vector2 = gate.pos + (cluster[0] - gate.pos).normalized() * 2.0
					b.play_card(team, i, p)
					return


func _hurt_group(b: Battle) -> Array:
	var best := [Vector2.ZERO, 0]
	for f: BUnit in b.units:
		if f.team != team or f.structure or f.hp > f.max_hp * 0.6:
			continue
		var n := 0
		for o: BUnit in b.units:
			if o.team == team and not o.structure and o.hp < o.max_hp * 0.7 and o.pos.distance_to(f.pos) < 2.5:
				n += 1
		if n > best[1]:
			best = [f.pos, n]
	return best


func _powers(b: Battle) -> void:
	for u: BUnit in b.units:
		if u.team != team or u.structure:
			continue
		var ab := b.ability_of(u)
		if ab.is_empty() or b.time < u.ability_ready_at or b.energy[team] < float(ab.get("cost", 0)) + 1.0:
			continue
		if level == 1 and _rng.randf() < 0.6:
			continue
		var r := float(ab.get("range", 0))
		match ab["type"]:
			"area_damage", "dash":
				var center := u.pos if ab.get("self", false) else Vector2.INF
				var best_n := 0
				for e: BUnit in b.units:
					if not b.can_target(team, e):
						continue
					if not ab.get("self", false) and u.pos.distance_to(e.pos) > r:
						continue
					var c: Vector2 = u.pos if ab.get("self", false) else e.pos
					var n := 0
					for o: BUnit in b.units:
						if b.can_target(team, o) and o.pos.distance_to(c) <= float(ab.get("radius", 1.0)):
							n += 3 if o.structure or o.kind == "king" else 1
					if n > best_n:
						best_n = n
						center = c
				if best_n >= (1 if ab["type"] == "dash" else 2):
					var p: Vector2 = center
					if ab["type"] == "dash":
						p = center - (center - u.pos).normalized() * 0.8
					b.cast_ability(u.id, p)
			"area_heal":
				if _hurt_group(b)[1] >= 2 and u.pos.distance_to(_hurt_group(b)[0]) < 3.0:
					b.cast_ability(u.id, u.pos)
			"area_buff":
				var near := 0
				for e: BUnit in b.enemies_of(team):
					if e.pos.distance_to(u.pos) < 3.0:
						near += 1
				if near >= 2:
					b.cast_ability(u.id, u.pos)


func _my_gate(b: Battle) -> BUnit:
	for u: BUnit in b.units:
		if u.team == team and u.kind == "gate":
			return u
	return null


## Defend when enemies come near home, attack when the army is big enough.
func _army(b: Battle) -> void:
	var home: Vector2 = Vector2(b.map["palaces"][team]["gate"])
	var army := b.heroes_of(team).filter(func(u): return u.role() != "miner")
	var invaders := []
	for e: BUnit in b.units:
		if e.team != team and not e.structure and e.pos.distance_to(home) < 7.0:
			invaders.append(e)
	var power := 0.0
	for u: BUnit in army:
		power += b.card_cost(u.kind)
	var need: float = [7.0, 6.0, 5.0][clampi(level - 1, 0, 2)]
	if level <= 0:
		need = 999.0   # tutorial: the computer only defends
	if power >= need:
		_attacking = true
	elif power < need * 0.3:
		_attacking = false
	var defenders := []
	var attackers := []
	for u: BUnit in army:
		if not invaders.is_empty() and (not _attacking or u.pos.distance_to(home) < 9.0):
			defenders.append(u)
		elif _attacking:
			attackers.append(u)
	if not invaders.is_empty() and not defenders.is_empty():
		var t: BUnit = invaders[0]
		for u: BUnit in defenders:
			if u.order == "" or (u.order == "move"):
				b.order_attack([u.id], t.id)
	if not attackers.is_empty():
		var target := _attack_target(b, attackers[0].pos)
		if target != null:
			var ids := []
			for u: BUnit in attackers:
				if u.order == "" or (u.order == "move" and u.order_pos.distance_to(target.pos) > 3.0):
					ids.append(u.id)
			if not ids.is_empty():
				b.order_attack(ids, target.id)
	elif not _attacking:
		# gather in front of the gate
		var rally := home + Vector2(0, 3 if team == 0 else -3)
		var ids := []
		for u: BUnit in army:
			if u.order == "" and u.pos.distance_to(rally) > 3.0 and u.target_id < 0:
				ids.append(u.id)
		if not ids.is_empty():
			b.order_move(ids, rally)


func _attack_target(b: Battle, from: Vector2) -> BUnit:
	var k := b.king(1 - team)
	if k != null and b.king_exposed(1 - team):
		return k
	var best: BUnit = null
	var best_d := INF
	for e: BUnit in b.units:
		if e.team == team or not (e.kind == "gate" or e.kind == "tower"):
			continue
		var d := from.distance_to(e.pos) + (2.0 if e.kind == "gate" else 0.0)
		if d < best_d:
			best = e
			best_d = d
	return best
