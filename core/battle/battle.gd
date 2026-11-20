class_name Battle
extends RefCounted
## A real-time battle between the Sun (team 0, bottom) and the Void (team 1, top).
##
## Pure rules: no Nodes, no graphics. The game calls step(dt) every frame
## (not while paused) and the screen reads `units` and the `events` list.
## Orders come from the player or BattleAI through the public functions:
##   order_move(ids, pos)  order_attack(ids, target_id)
##   play_card(team, card, pos)  cast_ability(unit_id, pos)  upgrade_palace(team)
## Every hero acts on its own: it fights enemies that come close, miners
## walk to crystal mines, healers heal friends, towers shoot.

const TICK := 0.05
const BURN_DPS := 45.0
const SAFETY_ENERGY_EVERY := 5.0
const HERO_RECHARGE := 5.0
const MAX_HEROES := 15   ## no miner alive: the palace makes a little energy so you are never stuck

var map: Dictionary
var w: int
var h: int
var time := 0.0
var units: Array = []              ## Array[BUnit], dead ones removed
var energy: Array = [0.0, 0.0]
var energy_max := 20.0
var palace_level: Array = [0, 0]
## cards[team] = Array of { id, ready_at, unit (the last hero summoned with it, or -1) }
## A hero card can be played again and again (energy is the limit); after each use it
## recharges for HERO_RECHARGE seconds. At most MAX_HEROES heroes per side on the field.
var cards: Array = [[], []]
var levels: Array = [{}, {}]       ## hero id -> level, per team
var summons: Array = [0, 0]       ## heroes summoned with cards, per team
var winner := -1                   ## -1 ongoing, 0/1 winner, 2 draw
var time_limit := 300.0
var events: Array = []
var explored: Array = []           ## per team: PackedByteArray (large map fog)
var rng := RandomNumberGenerator.new()

var _next_id := 1
var _by_id: Dictionary = {}
var _grids: Array = [null, null, null]   ## AStarGrid2D per team (2 = neutral monsters)
const NEUTRAL := 2
var biome := "meadow"
var world: Dictionary = {}         ## data/biomes.json entry of this world
var pickups: Array = []            ## treasure chests on the map: { id, pos }
var bonus_gold: Array = [0, 0]     ## gold from treasure and monsters, per team
var _treasure_at := 0.0
var _energy_well_timer := 0.0
var _next_pickup := 1
var _tick_n := 0
var _acc := 0.0
var _mine_owner: Dictionary = {}   ## Vector2i -> unit id working it
var _safety_timer: Array = [0.0, 0.0]
var _fog_timer := 0.0
var _visible: Array = [PackedByteArray(), PackedByteArray()]


## decks: two Arrays of 8 card ids. levels: per team { hero id: level }.
static func create(size: String, decks: Array, team_levels: Array = [{}, {}], seed_value: int = 7, p_biome: String = "meadow") -> Battle:
	var b := Battle.new()
	b.rng.seed = seed_value
	b.biome = p_biome
	b.world = BattleData.biome(p_biome)
	b.map = MapGen.make(size, seed_value, p_biome)
	b.w = b.map["w"]
	b.h = b.map["h"]
	b.levels = team_levels
	b.time_limit = float(BattleData.cfg()["maps"][size].get("time", 300))
	b.energy_max = BattleData.get_num("energy", "max", 20)
	for team in 2:
		b.energy[team] = BattleData.get_num("energy", "start", 5)
		for c in decks[team]:
			b.cards[team].append({ "id": c, "ready_at": 0.0, "unit": -1 })
		b.explored.append(PackedByteArray())
		b.explored[team].resize(b.w * b.h)
		b._visible[team].resize(b.w * b.h)
	b._build_grids()
	b._spawn_palaces()
	for team in 2:
		var i := 0
		for hero in BattleData.cfg().get("start_army", []):
			var spawn: Vector2i = b.map["palaces"][team]["spawn"]
			var dir := 1 if team == 0 else -1
			var p := Vector2(spawn.x + (i % 3 - 1) * 1.0, spawn.y + dir * (1 + i / 3))
			var u := b._spawn_hero(team, hero, p)
			i += 1
	b._spawn_monsters()
	b._treasure_at = float(BattleData.biomes().get("treasure", {}).get("first", 12.0))
	b._update_fog(true)
	return b


# ------------------------------------------------------------------ queries

func unit(id: int) -> BUnit:
	return _by_id.get(id, null)


func terrain_at(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return Chess.Terrain.WALL
	return map["terrain"][c.y * w + c.x]


func in_bounds(p: Vector2) -> bool:
	return p.x >= -0.5 and p.y >= -0.5 and p.x <= w - 0.5 and p.y <= h - 0.5


func king(team: int) -> BUnit:
	for u: BUnit in units:
		if u.team == team and u.kind == "king":
			return u
	return null


func enemies_of(team: int) -> Array:
	return units.filter(func(u): return u.team != team)


func heroes_of(team: int) -> Array:
	return units.filter(func(u): return u.team == team and not u.structure and u.kind != "king")


func is_over() -> bool:
	return winner >= 0


## The king hides behind his walls: he can only be hit once his gate or a tower has fallen.
func king_exposed(team: int) -> bool:
	var gate_up := false
	var towers := 0
	for u: BUnit in units:
		if u.team == team and u.kind == "gate":
			gate_up = true
		if u.team == team and u.kind == "tower":
			towers += 1
	return not gate_up or towers < 2


func can_target(attacker_team: int, target: BUnit) -> bool:
	if target.team == attacker_team:
		return false
	if target.kind == "king" and not king_exposed(target.team):
		return false
	return true


func is_visible(team: int, p: Vector2) -> bool:
	if not map["fog"]:
		return true
	var c := Vector2i(roundi(p.x), roundi(p.y))
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return false
	return _visible[team][c.y * w + c.x] == 1


func card_state(team: int, idx: int) -> Dictionary:
	return cards[team][idx]


## Seconds until the card can be played again (0 = ready).
func card_wait(team: int, idx: int) -> float:
	var c: Dictionary = cards[team][idx]
	return maxf(0.0, c["ready_at"] - time)


func army_full(team: int) -> bool:
	return heroes_of(team).size() >= MAX_HEROES


func card_cost(id: String) -> float:
	return float(BattleData.card(id).get("cost", 0))


func ability_of(u: BUnit) -> Dictionary:
	return u.data.get("ability", {})


func palace_upgrade_cost(team: int) -> int:
	var ups: Array = BattleData.cfg().get("palace_upgrades", [])
	return -1 if palace_level[team] >= ups.size() else int(ups[palace_level[team]]["cost"])


## Bonuses from the base village: a stronger palace and more energy at the start.
func apply_bonuses(team: int, palace_bonus: float, energy_bonus: float) -> void:
	for u: BUnit in units:
		if u.team == team and (u.structure or u.kind == "king"):
			u.max_hp *= 1.0 + palace_bonus
			u.hp = u.max_hp
	energy[team] = minf(energy_max, energy[team] + energy_bonus)


# ------------------------------------------------------------------ orders

## Walk to a spot. On the way heroes hit enemies already in reach, but don't chase.
func order_move(ids: Array, pos: Vector2) -> void:
	var n := ids.size()
	var i := 0
	for id in ids:
		var u := unit(id)
		if u == null or u.structure or u.speed <= 0.0:
			continue
		# spread a group around the spot so they don't all stand on one square
		var off := Vector2.ZERO
		if n > 1:
			var a := TAU * i / n
			off = Vector2(cos(a), sin(a)) * minf(1.2, 0.35 * n)
		u.order = "move"
		u.order_pos = _clamp_pos(pos + off)
		u.target_id = -1
		u.path = []
		u.repath_at = 0.0
		if u.role() == "miner":
			_release_mine(u)
		i += 1


func order_attack(ids: Array, target_id: int) -> void:
	var t := unit(target_id)
	if t == null:
		return
	for id in ids:
		var u := unit(id)
		if u == null or u.structure or not can_target(u.team, t):
			continue
		u.order = "attack"
		u.target_id = target_id
		u.path = []
		u.repath_at = 0.0
		if u.role() == "miner":
			_release_mine(u)


## Play the card at deck slot idx. Heroes appear at the palace gate, spells land on pos.
func play_card(team: int, idx: int, pos: Vector2 = Vector2.ZERO) -> bool:
	if is_over() or idx < 0 or idx >= cards[team].size():
		return false
	var c: Dictionary = cards[team][idx]
	var id: String = c["id"]
	if card_wait(team, idx) != 0.0 or energy[team] < card_cost(id):
		return false
	if BattleData.is_spell(id):
		if not in_bounds(pos) or not is_visible(team, pos):
			return false
		var sp := BattleData.spell(id)
		energy[team] -= card_cost(id)
		c["ready_at"] = time + float(sp.get("cooldown", 8))
		events.append({ "type": "spell", "team": team, "card": id, "pos": pos, "radius": float(sp.get("radius", 1.0)) })
		_resolve(sp, team, pos, null)
		return true
	if army_full(team):
		return false
	energy[team] -= card_cost(id)
	var spawn: Vector2i = map["palaces"][team]["spawn"]
	var u := _spawn_hero(team, id, Vector2(spawn) + Vector2(rng.randf_range(-0.6, 0.6), rng.randf_range(0.0, 0.6) * (1 if team == 0 else -1)))
	u.from_card = id
	c["unit"] = u.id
	c["ready_at"] = time + HERO_RECHARGE
	summons[team] += 1
	if pos != Vector2.ZERO and in_bounds(pos):
		order_move([u.id], pos)
	return true


## Use a hero's special power at pos (self powers ignore pos).
func cast_ability(unit_id: int, pos: Vector2) -> bool:
	var u := unit(unit_id)
	if u == null or is_over():
		return false
	var ab := ability_of(u)
	if ab.is_empty() or time < u.ability_ready_at or not u.can_act(time):
		return false
	var cost := float(ab.get("cost", 0))
	if energy[u.team] < cost:
		return false
	if ab.get("self", false):
		pos = u.pos
	elif u.pos.distance_to(pos) > float(ab.get("range", 5)) + 0.01:
		return false
	if ab["type"] == "dash" and not _passable_for(u, Vector2i(roundi(pos.x), roundi(pos.y))):
		return false
	energy[u.team] -= cost
	u.ability_ready_at = time + float(ab.get("cooldown", 10))
	events.append({ "type": "ability", "id": u.id, "ability": ab.get("id", ""), "pos": pos,
		"from": u.pos, "radius": float(ab.get("radius", 1.0)), "team": u.team })
	if ab["type"] == "dash":
		u.pos = pos
		u.path = []
	_resolve(ab, u.team, pos, u)
	return true


## Buy the next palace upgrade: towers hit harder, gate and towers get stronger.
func upgrade_palace(team: int) -> bool:
	var cost := palace_upgrade_cost(team)
	if cost < 0 or energy[team] < cost or is_over():
		return false
	energy[team] -= cost
	var ups: Array = BattleData.cfg()["palace_upgrades"]
	var old_bonus: float = 0.0 if palace_level[team] == 0 else float(ups[palace_level[team] - 1]["bonus"])
	palace_level[team] += 1
	var bonus: float = float(ups[palace_level[team] - 1]["bonus"])
	var k := (1.0 + bonus) / (1.0 + old_bonus)
	for u: BUnit in units:
		if u.team == team and (u.kind == "gate" or u.kind == "tower"):
			u.max_hp *= k
			u.hp = minf(u.max_hp, u.hp * k + u.max_hp * 0.15)
			u.dmg *= k
	events.append({ "type": "upgrade", "team": team, "level": palace_level[team] })
	return true


# ------------------------------------------------------------------ simulation

func take_events() -> Array:
	var e := events
	events = []
	return e


func step(dt: float) -> void:
	if is_over():
		return
	_acc += dt
	while _acc >= TICK and not is_over():
		_acc -= TICK
		_tick(TICK)


func _tick(dt: float) -> void:
	time += dt
	_tick_n += 1
	# Units act one after another; whoever acts second reacts to the first one's
	# move. Alternate the order every tick so neither kingdom always gets that edge.
	var order := units.duplicate()
	if _tick_n % 2 == 1:
		order.reverse()
	for u: BUnit in order:
		if u.hp <= 0.0:
			continue
		_effects(u, dt)
		if u.hp <= 0.0:
			continue
		if u.expires_at > 0.0 and time >= u.expires_at:
			_damage(u, u.hp + 1.0, null)
			continue
		if not u.can_act(time):
			continue
		if u.structure:
			_structure_think(u)
		else:
			_hero_think(u, dt)
	_separate()
	_economy(dt)
	_world_tick(dt)
	_fog_timer -= dt
	if _fog_timer <= 0.0:
		_fog_timer = 0.25
		_update_fog(false)
	if time >= time_limit and winner < 0:
		var s := [_score(0), _score(1)]
		winner = 2 if absf(s[0] - s[1]) < 0.01 else (0 if s[0] > s[1] else 1)
		events.append({ "type": "game_over", "winner": winner, "reason": "time" })


func _score(team: int) -> float:
	var total := 0.0
	for u: BUnit in units:
		if u.team == team and (u.structure or u.kind == "king") and u.kind != "wall":
			total += u.hp / u.max_hp
	return total


func _effects(u: BUnit, dt: float) -> void:
	if u.has_effect("burn", time):
		_damage(u, BURN_DPS * dt, null, true)
	# the world's special ground: lava burns, spores heal, candy gives a sugar rage
	if not u.structure and not u.flying and terrain_at(u.cell()) == Chess.Terrain.SPECIAL:
		var sp: Dictionary = world.get("special", {})
		if sp.has("dps"):
			_damage(u, float(sp["dps"]) * dt, null, true)
		if sp.has("heal"):
			_heal(u, float(sp["heal"]) * dt, true)
		if sp.has("effect"):
			u.effects[sp["effect"]] = time + 0.4


func _structure_think(u: BUnit) -> void:
	if u.kind != "tower" or time < u.attack_ready_at:
		return
	var best: BUnit = null
	var best_d := INF
	for e: BUnit in units:
		if e.team == u.team or e.structure or e.team == NEUTRAL or not can_target(u.team, e):
			continue
		var d := u.pos.distance_to(e.pos) - e.radius
		if d <= u.range_ and d < best_d:
			best = e
			best_d = d
	if best != null:
		u.attack_ready_at = time + u.rate
		events.append({ "type": "attack", "id": u.id, "target": best.id, "ranged": true })
		_damage(best, u.dmg, u)


func _hero_think(u: BUnit, dt: float) -> void:
	var t: BUnit = unit(u.target_id) if u.target_id >= 0 else null
	if t != null and (t.hp <= 0.0 or not can_target(u.team, t)) and u.role() != "healer":
		t = null
	if u.order == "attack" and t == null:
		u.order = ""
		u.target_id = -1
	if u.kind == "king":
		_fight_in_reach(u)
		return
	if u.team == NEUTRAL:
		_monster_think(u, dt)
		return
	match u.order:
		"attack":
			if _in_reach(u, t):
				_hit(u, t)
			else:
				_walk_toward(u, t.pos, dt, t)
		"move":
			# fight what is already in reach, but keep walking otherwise
			if u.role() == "healer" and _heal_in_reach(u):
				return
			if _fight_in_reach(u):
				return
			if u.pos.distance_to(u.order_pos) < 0.25:
				u.order = ""
				u.path = []
			else:
				_walk_toward(u, u.order_pos, dt, null)
		_:
			_idle_think(u, dt)


## No orders: miners mine, healers heal, everyone else fights enemies that come close.
func _idle_think(u: BUnit, dt: float) -> void:
	if u.role() == "healer":
		var f := _hurt_friend_near(u, u.range_ + 3.0)
		if f != null:
			if u.pos.distance_to(f.pos) <= u.range_:
				_hit(u, f)
			else:
				_walk_toward(u, f.pos, dt, f)
			return
	var aggro := u.range_ + float(BattleData.cfg().get("aggro_extra", 2.5))
	var e := _nearest_enemy(u, aggro)
	if u.role() == "miner":
		if e != null and _in_reach(u, e):
			_hit(u, e)
			return
		_mine(u, dt)
		return
	if e != null:
		if _in_reach(u, e):
			_hit(u, e)
		else:
			_walk_toward(u, e.pos, dt, e)


func _fight_in_reach(u: BUnit) -> bool:
	var e := _nearest_enemy(u, u.range_ + 0.5)
	if e != null and _in_reach(u, e):
		_hit(u, e)
		return true
	return false


func _heal_in_reach(u: BUnit) -> bool:
	var f := _hurt_friend_near(u, u.range_)
	if f != null:
		_hit(u, f)
		return true
	return false


func _hurt_friend_near(u: BUnit, radius: float) -> BUnit:
	var best: BUnit = null
	var worst := 0.98
	for f: BUnit in units:
		if f.team != u.team or f.structure or f == u:
			continue
		var frac := f.hp / f.max_hp
		if frac < worst and u.pos.distance_to(f.pos) <= radius:
			best = f
			worst = frac
	return best


func _nearest_enemy(u: BUnit, radius: float) -> BUnit:
	var best: BUnit = null
	var best_score := INF
	var prefers_structures: bool = u.data.get("prefers", "") == "structures"
	for e: BUnit in units:
		if not can_target(u.team, e) or e.kind == "wall" and not _blocks_way(u, e):
			continue
		if map["fog"] and not is_visible(u.team, e.pos):
			continue
		var d := u.pos.distance_to(e.pos) - e.radius
		if d > radius:
			continue
		var score := d
		if prefers_structures and not (e.structure or e.kind == "king"):
			score += 6.0
		if score < best_score:
			best = e
			best_score = score
	return best


func _blocks_way(_u: BUnit, _wall: BUnit) -> bool:
	return true


func _in_reach(u: BUnit, t: BUnit) -> bool:
	return t != null and u.pos.distance_to(t.pos) - t.radius <= u.range_


func _hit(u: BUnit, t: BUnit) -> void:
	u.facing = (t.pos - u.pos).normalized() if t.pos != u.pos else u.facing
	u.path = []
	if time < u.attack_ready_at:
		return
	var slow := 1.5 if u.has_effect("slow", time) else 1.0
	u.attack_ready_at = time + u.rate * slow
	if u.role() == "healer" and t.team == u.team:
		events.append({ "type": "attack", "id": u.id, "target": t.id, "ranged": true, "heal": true })
		_heal(t, u.heal * _level_mult(u))
		return
	if t.team == u.team:
		return
	var dmg := u.dmg * _level_mult(u)
	if u.has_effect("rage", time):
		dmg *= 1.3
	if t.structure or t.kind == "king":
		dmg *= float(u.data.get("siege", 1.0))
	if u.data.has("backstab") and t.target_id != u.id:
		dmg *= float(u.data["backstab"])
	events.append({ "type": "attack", "id": u.id, "target": t.id, "ranged": u.range_ > 2.0 })
	var splash := float(u.data.get("splash", 0.0))
	_damage(t, dmg, u)
	if u.data.has("slow"):
		t.effects["slow"] = time + float(u.data["slow"])
	if splash > 0.0:
		for e: BUnit in units.duplicate():
			if e != t and e.team != u.team and can_target(u.team, e) and e.pos.distance_to(t.pos) <= splash:
				_damage(e, dmg * 0.6, u)


func _level_mult(u: BUnit) -> float:
	return 1.0 + float(BattleData.cfg().get("level_bonus", 0.1)) * (u.level - 1)


func _damage(t: BUnit, amount: float, by: BUnit, quiet: bool = false) -> void:
	if t.hp <= 0.0:
		return
	if t.has_effect("shield", time):
		amount *= 0.5
	t.hp -= amount
	if by != null:
		t.last_hit_team = by.team
		t.last_hit_id = by.id
		t.last_hit_kind = by.kind
	if not quiet or int(time * 4) != int((time - TICK) * 4):
		events.append({ "type": "damage", "id": t.id, "amount": amount, "hp": t.hp })
	# a hero that gets hit while idle fights back
	if by != null and not t.structure and t.order == "" and t.target_id < 0 and t.role() != "healer" and t.kind != "king" and t.team != NEUTRAL and not by.structure:
		if can_target(t.team, by):
			t.target_id = by.id
			t.order = "attack"
	if t.hp <= 0.0:
		_die(t)


func _heal(t: BUnit, amount: float, quiet: bool = false) -> void:
	if t.hp <= 0.0 or t.structure:
		return
	var before := t.hp
	t.hp = minf(t.max_hp, t.hp + amount)
	if not quiet or (t.hp > before and int(time * 2) != int((time - TICK) * 2)):
		events.append({ "type": "heal", "id": t.id, "amount": (t.hp - before) * (1.0 if not quiet else 10.0), "hp": t.hp })


func _die(u: BUnit) -> void:
	u.hp = 0.0
	units.erase(u)
	_by_id.erase(u.id)
	_release_mine(u)
	var killer := unit(u.last_hit_id)
	events.append({ "type": "death", "id": u.id, "kind": u.kind, "team": u.team, "pos": u.pos, "by": u.last_hit_team,
		"killer": u.last_hit_kind, "killer_id": u.last_hit_id, "max_hp": u.max_hp,
		"killer_hp": killer.hp / killer.max_hp if killer != null else 1.0, "terrain": terrain_at(u.cell()) })
	if u.team == NEUTRAL and u.last_hit_team in [0, 1]:
		var r: Dictionary = BattleData.biomes().get("monster_reward", {})
		_add_energy(u.last_hit_team, float(r.get("energy", 6)), null)
		bonus_gold[u.last_hit_team] += int(r.get("gold", 25))
		events.append({ "type": "monster_slain", "team": u.last_hit_team, "kind": u.kind, "pos": u.pos })
	if u.kind == "gate" or u.kind == "wall":
		_set_cell_open(u.cell(), true)
	if u.kind == "tower":
		# a fallen tower leaves a hole in the wall (the tower square and the wall next to it)
		var c := u.cell()
		var gate: Vector2i = map["palaces"][u.team]["gate"]
		var inward := Vector2i(signi(gate.x - c.x), 0)
		for cell in [c, c + inward]:
			map["terrain"][cell.y * w + cell.x] = Chess.Terrain.CASTLE
			_set_cell_open(cell, true)
		events.append({ "type": "breach", "team": u.team, "cells": [c, c + inward] })
	if u.kind == "king":
		winner = 1 - u.team
		events.append({ "type": "game_over", "winner": winner, "reason": "king" })


func respawn_time(_card_id: String) -> float:
	return HERO_RECHARGE


## Area powers and spells: area_damage, area_heal, area_buff, dash, wall.
func _resolve(ab: Dictionary, team: int, pos: Vector2, caster: BUnit) -> void:
	var radius := float(ab.get("radius", 1.0))
	var effect: String = ab.get("effect", "")
	var dur := float(ab.get("duration", 0.0))
	var mult := _level_mult(caster) if caster != null else 1.0
	match ab["type"]:
		"area_damage", "dash":
			for e: BUnit in units.duplicate():
				if e.team == team or not can_target(team, e) or e.pos.distance_to(pos) > radius + e.radius:
					continue
				var dmg := float(ab.get("damage", 0)) * mult
				if e.structure:
					dmg *= 0.5
				_damage(e, dmg, caster)
				if effect != "" and e.hp > 0.0 and not e.structure:
					e.effects[effect] = time + dur
		"area_heal":
			for f: BUnit in units:
				if f.team == team and not f.structure and f.pos.distance_to(pos) <= radius:
					_heal(f, float(ab.get("heal", 0)) * mult)
		"area_buff":
			for f: BUnit in units:
				if f.team == team and not f.structure and f.pos.distance_to(pos) <= radius:
					f.effects[effect] = time + dur
		"wall":
			var c := Vector2i(roundi(pos.x), roundi(pos.y))
			if not _passable_for_team(team, c):
				return
			var wall := _new_unit(team, "wall", Vector2(c))
			wall.structure = true
			wall.radius = 0.5
			wall.hp = float(ab.get("hp", 700))
			wall.max_hp = wall.hp
			wall.speed = 0.0
			wall.dmg = 0.0
			wall.expires_at = time + dur
			_set_cell_blocked_for_enemies(team, c)
			events.append({ "type": "spawn", "id": wall.id })


# ------------------------------------------------------------------ the world

## A neutral monster guards its camp: it attacks anyone who comes close and
## goes back home (healing) when the enemies leave or it is lured too far.
func _monster_think(u: BUnit, dt: float) -> void:
	var t: BUnit = unit(u.target_id) if u.target_id >= 0 else null
	if t == null or t.hp <= 0.0 or t.pos.distance_to(u.home) > 5.5:
		t = null
		u.target_id = -1
		var best_d := 2.6
		for e: BUnit in units:
			if e.team == NEUTRAL or e.structure or e.kind == "king":
				continue
			var d := e.pos.distance_to(u.home)
			if d < best_d:
				best_d = d
				t = e
		if t != null:
			u.target_id = t.id
	if t != null:
		if _in_reach(u, t):
			_hit(u, t)
		else:
			_walk_toward(u, t.pos, dt, t)
		return
	u.order = ""
	if u.pos.distance_to(u.home) > 0.3:
		_walk_toward(u, u.home, dt, null)
	else:
		_heal(u, 40.0 * dt, true)


func _spawn_monsters() -> void:
	var kind: String = world.get("monster", "goblin")
	var d: Dictionary = BattleData.biomes().get("monsters", {}).get(kind, {})
	for c in map.get("camps", []):
		var u := _new_unit(NEUTRAL, kind, Vector2(c))
		u.data = d.duplicate()
		u.data["role"] = "monster"
		u.max_hp = float(d.get("hp", 1000))
		u.hp = u.max_hp
		u.dmg = float(d.get("dmg", 60))
		u.rate = float(d.get("rate", 1.2))
		u.range_ = float(d.get("range", 1.3))
		u.speed = float(d.get("speed", 1.2))
		u.radius = 0.45
		u.home = Vector2(c)
		u.facing = Vector2(0, 1)
		events.append({ "type": "spawn", "id": u.id })


## Shrines, treasure chests.
func _world_tick(dt: float) -> void:
	var sh_data: Dictionary = BattleData.biomes().get("shrines", {})
	_energy_well_timer += dt
	var well_tick := _energy_well_timer >= float(sh_data.get("energy", {}).get("every", 3.0))
	if well_tick:
		_energy_well_timer = 0.0
	for sh in map.get("shrines", []):
		var p := Vector2(sh["pos"])
		var info: Dictionary = sh_data.get(sh["type"], {})
		var r := float(info.get("radius", 1.6))
		var present := {}
		for u: BUnit in units:
			if u.structure or u.team == NEUTRAL or u.pos.distance_to(p) > r:
				continue
			present[u.team] = true
			match sh["type"]:
				"heal":
					_heal(u, float(info.get("heal", 40)) * dt, true)
				"power":
					u.effects["rage"] = time + 0.4
		if sh["type"] == "energy" and well_tick and present.size() == 1:
			var team: int = present.keys()[0]
			_add_energy(team, 1.0, null)
			events.append({ "type": "shrine", "team": team, "pos": p })
	# treasure chests appear in pairs (mirrored, so it is fair) and the first hero to touch one wins it
	var tr: Dictionary = BattleData.biomes().get("treasure", {})
	if time >= _treasure_at:
		_treasure_at = time + float(tr.get("every", 25.0))
		_spawn_treasure()
	for p in pickups.duplicate():
		for u: BUnit in units:
			if u.structure or u.team == NEUTRAL or u.kind == "king" or u.pos.distance_to(p["pos"]) > 0.7:
				continue
			pickups.erase(p)
			_add_energy(u.team, float(tr.get("energy", 4)), u)
			bonus_gold[u.team] += int(tr.get("gold", 15))
			events.append({ "type": "treasure", "team": u.team, "id": p["id"], "pos": p["pos"], "by": u.id })
			break


func _spawn_treasure() -> void:
	if pickups.size() >= 4:
		return
	var mid := (h - 1) / 2
	for attempt in 20:
		var c := Vector2i(rng.randi_range(1, w - 2), rng.randi_range(maxi(6, mid - 5), mid - 1))
		var mirror := Vector2i(w - 1 - c.x, h - 1 - c.y)
		if terrain_at(c) in [Chess.Terrain.PLAIN, Chess.Terrain.SPECIAL, Chess.Terrain.FOREST, Chess.Terrain.HILL]:
			for cc in [c, mirror]:
				pickups.append({ "id": _next_pickup, "pos": Vector2(cc) })
				events.append({ "type": "treasure_spawn", "id": _next_pickup, "pos": Vector2(cc) })
				_next_pickup += 1
			return


# ------------------------------------------------------------------ economy

func _economy(dt: float) -> void:
	for team in 2:
		var has_miner := false
		for u: BUnit in units:
			if u.team == team and u.role() == "miner":
				has_miner = true
				break
		if not has_miner:
			_safety_timer[team] += dt
			if _safety_timer[team] >= SAFETY_ENERGY_EVERY:
				_safety_timer[team] = 0.0
				_add_energy(team, 1.0, null)


func _add_energy(team: int, amount: float, from: BUnit) -> void:
	energy[team] = minf(energy_max, energy[team] + amount)
	events.append({ "type": "energy", "team": team, "amount": amount, "id": from.id if from else -1 })


## A miner walks to the nearest free mine and digs crystals into energy.
func _mine(u: BUnit, dt: float) -> void:
	if u.mine_cell.x < 0:
		var best := Vector2i(-1, -1)
		var best_d := INF
		for m in map["mines"]:
			if _mine_owner.has(m) and _mine_owner[m] != u.id:
				continue
			var d := u.pos.distance_to(Vector2(m))
			# own half first: enemy mines count as further away
			if (m.y > h / 2) != (u.team == 1):
				d += 8.0
			if d < best_d:
				best = m
				best_d = d
		if best.x < 0:
			return
		u.mine_cell = best
		_mine_owner[best] = u.id
	var target := Vector2(u.mine_cell)
	if u.pos.distance_to(target) > 0.45:
		_walk_toward(u, target, dt, null)
		return
	u.mine_timer += dt
	if u.mine_timer >= BattleData.get_num("energy", "mine_interval", 2.2):
		u.mine_timer = 0.0
		_add_energy(u.team, BattleData.get_num("energy", "mine_amount", 1) * _level_mult(u), u)


func _release_mine(u: BUnit) -> void:
	if u.mine_cell.x >= 0 and _mine_owner.get(u.mine_cell, -1) == u.id:
		_mine_owner.erase(u.mine_cell)
	u.mine_cell = Vector2i(-1, -1)
	u.mine_timer = 0.0


# ------------------------------------------------------------------ movement

func _speed(u: BUnit) -> float:
	var s := u.speed
	if u.has_effect("slow", time):
		s *= 0.5
	if u.has_effect("rage", time):
		s *= 1.25
	if not u.flying and terrain_at(u.cell()) == Chess.Terrain.FOREST:
		s *= 0.65
	if not u.flying and terrain_at(u.cell()) == Chess.Terrain.SPECIAL:
		s *= float(world.get("special", {}).get("speed", 1.0))
	return s


func _walk_toward(u: BUnit, goal: Vector2, dt: float, chasing: BUnit) -> void:
	var sp := _speed(u)
	if sp <= 0.0:
		return
	if u.flying:
		_step_to(u, goal, sp * dt)
		return
	if u.path.is_empty() or time >= u.repath_at:
		u.repath_at = time + (0.6 if chasing != null else 1.5)
		var grid: AStarGrid2D = _grids[u.team]
		var from := _clamp_cell(u.cell())
		var to := _clamp_cell(Vector2i(roundi(goal.x), roundi(goal.y)))
		var ids := grid.get_id_path(from, to, true)
		u.path = []
		for i in range(1, ids.size()):
			u.path.append(Vector2(ids[i]))
		if not u.path.is_empty() and chasing == null and to == Vector2i(ids[ids.size() - 1]):
			u.path[u.path.size() - 1] = goal
		if u.path.is_empty():
			u.path = [goal] if grid.is_in_boundsv(to) and not grid.is_point_solid(to) else []
	if u.path.is_empty():
		return
	var left := sp * dt
	while left > 0.0 and not u.path.is_empty():
		var nxt: Vector2 = u.path[0]
		var d := u.pos.distance_to(nxt)
		if d <= left:
			u.pos = nxt
			left -= d
			u.path.pop_front()
		else:
			_step_to(u, nxt, left)
			left = 0.0


func _step_to(u: BUnit, goal: Vector2, dist: float) -> void:
	var v := goal - u.pos
	if v.length() < 0.0001:
		return
	u.facing = v.normalized()
	u.pos += v.normalized() * minf(dist, v.length())


## Heroes of one team push gently apart so a group does not melt into one spot.
func _separate() -> void:
	var movers := units.filter(func(u): return not u.structure and u.speed > 0.0)
	for i in movers.size():
		for j in range(i + 1, movers.size()):
			var a: BUnit = movers[i]
			var b: BUnit = movers[j]
			var v: Vector2 = b.pos - a.pos
			var d := v.length()
			var min_d := (a.radius + b.radius) * 1.1
			if d < min_d:
				var push := (v.normalized() if d > 0.001 else Vector2(1, 0)) * (min_d - d) * 0.5
				var na: Vector2 = a.pos - push
				var nb: Vector2 = b.pos + push
				if _passable_for(a, Vector2i(roundi(na.x), roundi(na.y))):
					a.pos = na
				if _passable_for(b, Vector2i(roundi(nb.x), roundi(nb.y))):
					b.pos = nb


func _clamp_cell(c: Vector2i) -> Vector2i:
	return Vector2i(clampi(c.x, 0, w - 1), clampi(c.y, 0, h - 1))


func _clamp_pos(p: Vector2) -> Vector2:
	return Vector2(clampf(p.x, 0, w - 1), clampf(p.y, 0, h - 1))


func _passable_for(u: BUnit, c: Vector2i) -> bool:
	if u.flying:
		return c.x >= 0 and c.y >= 0 and c.x < w and c.y < h
	return _passable_for_team(u.team, c)


func _passable_for_team(team: int, c: Vector2i) -> bool:
	var g: AStarGrid2D = _grids[team]
	return g.is_in_boundsv(c) and not g.is_point_solid(c)


func _build_grids() -> void:
	for team in 3:
		var g := AStarGrid2D.new()
		g.region = Rect2i(0, 0, w, h)
		g.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		g.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		g.update()
		for y in h:
			for x in w:
				var t: int = map["terrain"][y * w + x]
				if t == Chess.Terrain.WALL or t == Chess.Terrain.WATER:
					g.set_point_solid(Vector2i(x, y), true)
				elif t == Chess.Terrain.FOREST:
					g.set_point_weight_scale(Vector2i(x, y), 1.6)
		# the king's floor: only the king lives there, but friends may walk in to defend
		_grids[team] = g


func _set_cell_open(c: Vector2i, _open: bool) -> void:
	for team in 3:
		var t := terrain_at(c)
		_grids[team].set_point_solid(c, t == Chess.Terrain.WALL or t == Chess.Terrain.WATER)


func _set_cell_blocked_for_enemies(team: int, c: Vector2i) -> void:
	for other in 3:
		if other != team:
			_grids[other].set_point_solid(c, true)


# ------------------------------------------------------------------ spawning

func _new_unit(team: int, kind: String, pos: Vector2) -> BUnit:
	var u := BUnit.new()
	u.id = _next_id
	_next_id += 1
	u.team = team
	u.kind = kind
	u.pos = pos
	u.facing = Vector2(0, 1) if team == 0 else Vector2(0, -1)
	units.append(u)
	_by_id[u.id] = u
	return u


func _spawn_hero(team: int, id: String, pos: Vector2) -> BUnit:
	var d := BattleData.hero(id)
	var u := _new_unit(team, id, pos)
	u.data = d
	u.level = int(levels[team].get(id, 1))
	var m := _level_mult(u)
	u.max_hp = float(d.get("hp", 100)) * m
	u.hp = u.max_hp
	u.dmg = float(d.get("dmg", 10))
	u.heal = float(d.get("heal", 0))
	u.rate = float(d.get("rate", 1.0))
	u.range_ = float(d.get("range", 1.2))
	u.speed = float(d.get("speed", 1.5))
	u.flying = bool(d.get("flying", false))
	u.radius = 0.45 if id in ["giant", "dragon", "ballista"] else 0.3
	events.append({ "type": "spawn", "id": u.id })
	return u


func _spawn_palaces() -> void:
	var cfg: Dictionary = BattleData.cfg()["structures"]
	for team in 2:
		var p: Dictionary = map["palaces"][team]
		var gate := _new_unit(team, "gate", Vector2(p["gate"]))
		gate.structure = true
		gate.radius = 0.5
		gate.max_hp = float(cfg["gate"]["hp"])
		gate.hp = gate.max_hp
		gate.speed = 0.0
		gate.dmg = 0.0
		_set_cell_blocked_for_enemies(team, p["gate"])
		for tc in p["towers"]:
			var t := _new_unit(team, "tower", Vector2(tc))
			t.structure = true
			t.radius = 0.5
			t.max_hp = float(cfg["tower"]["hp"])
			t.hp = t.max_hp
			t.dmg = float(cfg["tower"]["dmg"])
			t.rate = float(cfg["tower"]["rate"])
			t.range_ = float(cfg["tower"]["range"])
			t.speed = 0.0
		_spawn_hero(team, "king", Vector2(p["king"]))


# ------------------------------------------------------------------ fog

func _update_fog(_first: bool) -> void:
	if not map["fog"]:
		return
	var vision := int(BattleData.cfg().get("vision", 6))
	for team in 2:
		var vis: PackedByteArray = _visible[team]
		vis.fill(0)
		for u: BUnit in units:
			if u.team != team:
				continue
			var c := u.cell()
			var r := vision + (1 if u.structure else 0)
			for y in range(maxi(0, c.y - r), mini(h, c.y + r + 1)):
				for x in range(maxi(0, c.x - r), mini(w, c.x + r + 1)):
					if (x - c.x) * (x - c.x) + (y - c.y) * (y - c.y) <= r * r:
						vis[y * w + x] = 1
						explored[team][y * w + x] = 1
		_visible[team] = vis
