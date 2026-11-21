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
## walk to crystal mines, healers heal friends.
##
## CHESS-LIKE MOVES: every turn a hero may walk only `moves` squares (heroes.json);
## reach_cells(u) lists the squares it can reach this turn (the screen lights them).
## The king can never be hurt. GAME MODES (how you win, `mode`):
##   mate   - checkmate: break the gate, then threaten the king's square and every
##            square around him; if that is still so when a turn ends, you win
##   crown  - steal the enemy crown from his throne room and carry it home
##   throne - keep a hero on the enemy throne for THRONE_TIME seconds (3 turns)
##   runes  - bring RUNES_TO_WIN magic runes from the field to your own king

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
var _order_rng := RandomNumberGenerator.new()
var _raise_ready: Dictionary = {}
## Which power each hero uses, per team: { hero id: 0 or 1 } (picked in the deck screen).
var loadout: Array = [{}, {}]
## DAY AND NIGHT: a cycle of SKY_CYCLE turns. Day = the Sun is stronger, night = the
## Void is stronger, and between them comes an ECLIPSE: all powers recharge at once.
## (An eclipse both before the night and before the day keeps it fair.)
const TURN := 5.0
const SKY_CYCLE := ["day", "day", "eclipse", "night", "night", "eclipse"]
const SKY_BONUS_DMG := 1.3
const SKY_BONUS_SPEED := 1.15
var _sky_turn := -1
## Where in the day/night cycle this battle starts (random, so neither side always gets the first day).
var sky_offset := 0
## Tools only (fairness checks): the sky favours nobody.
var no_sky := false
var _acc := 0.0
var _mine_owner: Dictionary = {}   ## Vector2i -> unit id working it
var _safety_timer: Array = [0.0, 0.0]
var _fog_timer := 0.0
var _visible: Array = [PackedByteArray(), PackedByteArray()]

const MODES := ["mate", "crown", "throne", "runes"]
const THRONE_TIME := 15.0
const RUNES_TO_WIN := 3
const RUNE_BACK := 8.0
var mode := "mate"
var in_check: Array = [false, false]      ## is this team's king in check right now?
var mate_cells: Array = [[], []]          ## threatened squares around this team's king
var crowns: Array = []                    ## { team, pos, home, carrier }
var throne_time: Array = [0.0, 0.0]       ## seconds this team sat on the ENEMY throne
var runes: Array = []                     ## { id, pos, home, carrier, back_at }
var rune_count: Array = [0, 0]


## decks: two Arrays of 8 card ids. levels: per team { hero id: level }.
static func create(size: String, decks: Array, team_levels: Array = [{}, {}], seed_value: int = 7, p_biome: String = "meadow", p_mode: String = "mate") -> Battle:
	var b := Battle.new()
	b.rng.seed = seed_value
	b._order_rng.seed = seed_value * 31 + 5
	b.mode = p_mode if p_mode in MODES else "mate"
	b.biome = p_biome
	# every start in the cycle is equally likely, so over many battles no kingdom gets more good turns
	b.sky_offset = b.rng.randi_range(0, SKY_CYCLE.size() - 1)
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
			# mirrored for the Void so both armies stand the same way (fair)
			var p := Vector2(spawn.x + dir * (i % 3 - 1) * 1.0, spawn.y + dir * (1 + i / 3))
			var u := b._spawn_hero(team, hero, p)
			i += 1
	b._spawn_monsters()
	b._setup_mode()
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


func gate(team: int) -> BUnit:
	for u: BUnit in units:
		if u.team == team and u.kind == "gate":
			return u
	return null


## The king can never be hurt: you win by the game mode instead (mate, crown...).
func can_target(attacker_team: int, target: BUnit) -> bool:
	if target.team == attacker_team or target.kind == "king":
		return false
	return true


## How many squares this hero may walk in one turn (the sky, rage, slow and a
## heavy crown change it).
func move_tiles(u: BUnit, turn_index: int = -1) -> int:
	var m := int(u.data.get("moves", 3))
	var fav := favoured_team() if turn_index < 0 else favoured_team_at(turn_index)
	if u.team == fav:
		m += 1
	if u.has_effect("rage", time):
		m += 1
	if u.has_effect("slow", time) or u.carry == "crown":
		m -= 1
	return maxi(1, m)


## The squares a hero can still reach this turn: { Vector2i: steps }. Steps count
## like a chess king (straight 1, diagonal 1.4). planning = true: the squares for
## the coming turn (the plan phase, when the hero gets all its squares back).
func reach_cells(u: BUnit, planning: bool = false) -> Dictionary:
	var out := {}
	if u == null or u.structure or u.speed <= 0.0 or u.kind == "king":
		return out
	var limit := (float(move_tiles(u, next_turn_index())) if planning else minf(u.budget, float(move_tiles(u)))) + 0.05
	var start := u.cell()
	out[start] = 0.0
	var open := [start]
	while not open.is_empty():
		# small maps: a simple scan for the cheapest open square is fast enough
		var bi := 0
		for i in open.size():
			if out[open[i]] < out[open[bi]]:
				bi = i
		var c: Vector2i = open[bi]
		open.remove_at(bi)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if not _passable_for(u, n):
				continue
			if d.x != 0 and d.y != 0 and not u.flying and (not _passable_for(u, Vector2i(c.x + d.x, c.y)) or not _passable_for(u, Vector2i(c.x, c.y + d.y))):
				continue
			var cost: float = out[c] + (1.414 if d.x != 0 and d.y != 0 else 1.0)
			if cost > limit or (out.has(n) and out[n] <= cost):
				continue
			out[n] = cost
			open.append(n)
	return out


## The turn that starts when the plan phase ends.
func next_turn_index() -> int:
	return roundi(time / TURN)


## Enemies this hero could hit this turn (walk + its reach).
func attackable(u: BUnit, planning: bool = false) -> Array:
	var cells := reach_cells(u, planning)
	var res := []
	for e: BUnit in units:
		if not can_target(u.team, e):
			continue
		if hidden_from(e, u.pos):
			continue
		for c in cells:
			if Vector2(c).distance_to(e.pos) - e.radius <= u.range_ + 0.1:
				res.append(e)
				break
	return res


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
	var list: Array = u.data.get("abilities", [])
	if list.is_empty():
		return u.data.get("ability", {})
	if u.team > 1:
		return {}
	var i := clampi(int(loadout[u.team].get(u.kind, 0)), 0, list.size() - 1)
	return list[i]


## The sky in the given turn (0 = first turn): "day", "night" or "eclipse".
static func sky_of_turn(turn_index: int) -> String:
	return SKY_CYCLE[turn_index % SKY_CYCLE.size()]


## The sky in turn `turn_index` of THIS battle.
func sky_at(turn_index: int) -> String:
	return sky_of_turn(turn_index + sky_offset)


func sky() -> String:
	return sky_at(int(time / TURN))


## Which kingdom the sky favours now (-1 = nobody).
func favoured_team() -> int:
	return favoured_team_at(int(time / TURN))


func favoured_team_at(turn_index: int) -> int:
	if no_sky:
		return -1
	match sky_at(turn_index):
		"day": return 0
		"night": return 1
	return -1


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
	# a little spread so new heroes do not stand on each other (mirrored, so it stays fair)
	var k: int = summons[team]
	var off := Vector2([0.0, -0.4, 0.4, -0.2, 0.2][k % 5], 0.15 * (k % 3))
	var u := _spawn_hero(team, id, Vector2(spawn) + off * (1 if team == 0 else -1))
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


## Buy the next palace upgrade: the gate gets stronger and the king hits harder.
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
		if u.team == team and (u.kind == "gate" or u.kind == "king"):
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
	time = roundf(time * 10000.0) / 10000.0   # no creeping rounding error: turns end exactly
	_tick_n += 1
	var turn_index := int(time / TURN)
	if turn_index != _sky_turn:
		_sky_turn = turn_index
		_turn_start(turn_index)
		if is_over():
			return
		var now := sky_at(turn_index)
		events.append({ "type": "sky", "sky": now, "turn": turn_index })
		if now == "eclipse":
			# the eclipse: every hero's power is ready at once
			for u: BUnit in units:
				u.ability_ready_at = 0.0
			events.append({ "type": "eclipse" })
	# Units act one after another; whoever acts second reacts to the first one's
	# move. Alternate the order every tick so neither kingdom always gets that edge.
	# (a fair coin each tick: plain alternation repeated the same pattern every
	# turn, because a turn has an even number of ticks)
	var order := units.duplicate()
	if _order_rng.randi() % 2 == 1:
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
	_mode_tick(dt)
	_fog_timer -= dt
	if _fog_timer <= 0.0:
		_fog_timer = 0.25
		_update_fog(false)
	if time >= time_limit and winner < 0:
		var s := [_score(0) - _score_lost(1), _score(1) - _score_lost(0)]
		winner = 2 if absf(s[0] - s[1]) < 0.01 else (0 if s[0] > s[1] else 1)
		events.append({ "type": "game_over", "winner": winner, "reason": "time" })


## Time is up: who got further in the game mode (and broke more of the enemy gate)?
func _score(team: int) -> float:
	return mode_progress(team) * 3.0


func _score_lost(team: int) -> float:
	var g := gate(team)
	return 0.0 if g == null else g.hp / g.max_hp


## How close this team is to winning the game mode, 0..1 (the HUD shows it).
func mode_progress(team: int) -> float:
	match mode:
		"mate":
			var zone := king_zone(1 - team)
			return 0.0 if zone.is_empty() else float(mate_cells[1 - team].size()) / zone.size()
		"crown":
			for cr in crowns:
				if cr["team"] != team and cr["carrier"] >= 0:
					var home := Vector2(map["palaces"][team]["spawn"])
					var start: float = Vector2(cr["home"]).distance_to(home)
					return clampf(1.0 - Vector2(cr["pos"]).distance_to(home) / maxf(1.0, start), 0.1, 0.95)
			return 0.0
		"throne":
			return throne_time[team] / THRONE_TIME
		"runes":
			return float(rune_count[team]) / RUNES_TO_WIN
	return 0.0


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


func _structure_think(_u: BUnit) -> void:
	pass   # gates and magic walls only stand in the way


func _hero_think(u: BUnit, dt: float) -> void:
	var t: BUnit = unit(u.target_id) if u.target_id >= 0 else null
	if t != null and (t.hp <= 0.0 or not can_target(u.team, t)) and u.role() != "healer":
		t = null
	if u.order == "attack" and t == null:
		u.order = ""
		u.target_id = -1
	if u.kind == "king":
		# the king fights back and steps away from danger inside his palace
		if not _fight_in_reach(u) and u.order == "move":
			if u.pos.distance_to(u.order_pos) < 0.1:
				u.order = ""
			else:
				_walk_toward(u, u.order_pos, dt, null)
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


## A hero sitting on the enemy throne stays there and only hits what is in reach.
func _on_enemy_throne(u: BUnit) -> bool:
	return mode == "throne" and u.team in [0, 1] and u.pos.distance_to(Vector2(map["palaces"][1 - u.team]["seat"])) <= 0.75


## No orders: miners mine, healers heal, everyone else fights enemies that come close.
func _idle_think(u: BUnit, dt: float) -> void:
	if _on_enemy_throne(u):
		_fight_in_reach(u)
		return
	if _kite(u, dt):
		return
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


## Archers step back from melee enemies that come too close, then shoot again.
func _kite(u: BUnit, dt: float) -> bool:
	if u.style() != "kite":
		return false
	for e: BUnit in units:
		if e.team == u.team or e.structure or e.range_ > 2.0 or not can_target(u.team, e):
			continue
		if e.pos.distance_to(u.pos) < 1.3:
			var away := (u.pos - e.pos).normalized()
			var goal := u.pos + away * 2.0
			if _passable_for(u, Vector2i(roundi(goal.x), roundi(goal.y))):
				_step_to(u, goal, _speed(u) * dt)
				return true
	return false


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


## A hidden assassin can only be found up close.
func hidden_from(e: BUnit, viewer_pos: Vector2) -> bool:
	return e.style() == "stealth" and time > e.revealed_until and e.pos.distance_to(viewer_pos) > 1.6


func _nearest_enemy(u: BUnit, radius: float) -> BUnit:
	var best: BUnit = null
	var best_score := INF
	var prefers_structures: bool = u.data.get("prefers", "") == "structures"
	for e: BUnit in units:
		if not can_target(u.team, e) or e.kind == "wall" and not _blocks_way(u, e):
			continue
		if map["fog"] and not is_visible(u.team, e.pos):
			continue
		if hidden_from(e, u.pos):
			continue
		# the bone guard draws every enemy near it to attack him
		if e.style() == "taunt" and e.pos.distance_to(u.pos) <= 2.6 and not u.structure:
			return e
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
	# the ballista must stand still a moment before it can shoot
	if u.style() == "setup" and time - u.still_since < 1.0:
		return
	var slow := 1.5 if u.has_effect("slow", time) else 1.0
	# a friendly bard close by plays a battle song: 25% faster attacks
	for f: BUnit in units:
		if f.team == u.team and f.style() == "song" and f.pos.distance_to(u.pos) <= 2.6:
			slow *= 0.75
			break
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
	if u.team == favoured_team():
		dmg *= SKY_BONUS_DMG
	if t.structure or t.kind == "king":
		dmg *= float(u.data.get("siege", 1.0))
	if u.data.has("backstab") and t.target_id != u.id:
		dmg *= float(u.data["backstab"])
	var extra := {}
	match u.style():
		"pack":       # soldiers fight better together
			var friends := 0
			for f: BUnit in units:
				if f != u and f.team == u.team and f.kind == u.kind and f.pos.distance_to(u.pos) < 1.6:
					friends += 1
			dmg *= 1.0 + 0.15 * mini(friends, 3)
		"momentum":   # a knight that charged in hits twice as hard and stuns
			if u.walked >= 3.0:
				dmg *= 2.0
				extra["stun"] = 0.6
				events.append({ "type": "trait", "id": u.id, "trait": "momentum", "pos": t.pos })
		"stealth":    # attacking reveals the assassin for a moment
			u.revealed_until = time + 3.0
	u.walked = 0.0
	events.append({ "type": "attack", "id": u.id, "target": t.id, "ranged": u.range_ > 2.0 })
	_damage(t, dmg, u)
	if extra.has("stun") and t.hp > 0.0 and not t.structure:
		t.effects["stun"] = time + float(extra["stun"])
	if u.data.has("slow") and not t.structure:
		t.effects["slow"] = time + float(u.data["slow"])
	match u.style():
		"scorch":     # fire sets the target burning
			if t.hp > 0.0 and not t.structure:
				t.effects["burn"] = time + 2.0
		"knockback":  # the giant throws heroes back
			if t.hp > 0.0 and not t.structure and t.kind != "king":
				var away := (t.pos - u.pos).normalized()
				var np := t.pos + away * 1.2
				if _passable_for(t, Vector2i(roundi(np.x), roundi(np.y))):
					t.pos = np
					t.path = []
		"chain":      # the queen's bolt jumps to two more enemies
			var last := t
			var hit_ids := [t.id]
			for k in 2:
				var nxt: BUnit = null
				var best := 2.6
				for e: BUnit in units:
					if hit_ids.has(e.id) or e.team == u.team or e.structure or not can_target(u.team, e):
						continue
					var dd := e.pos.distance_to(last.pos)
					if dd < best:
						best = dd
						nxt = e
				if nxt == null:
					break
				hit_ids.append(nxt.id)
				events.append({ "type": "chain", "from": last.pos, "to": nxt.pos })
				_damage(nxt, dmg * 0.6, u)
				last = nxt
		"breath":     # the dragon breathes fire on everyone in front of it
			for e: BUnit in units.duplicate():
				if e == t or e.team == u.team or not can_target(u.team, e):
					continue
				var v := e.pos - u.pos
				if v.length() <= u.range_ + 1.2 and v.normalized().dot(u.facing) > 0.6:
					_damage(e, dmg * 0.7, u)
	var splash := float(u.data.get("splash", 0.0))
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
	# the stone golem hardly feels shots from far away
	if t.style() == "stone" and by != null and by.range_ > 2.0:
		amount *= 0.5
	t.hp -= amount
	if by != null:
		t.last_hit_team = by.team
		t.last_hit_id = by.id
		t.last_hit_kind = by.kind
	if not quiet or int(time * 4) != int((time - TICK) * 4):
		events.append({ "type": "damage", "id": t.id, "amount": amount, "hp": t.hp })
	# a hero that gets hit while idle fights back
	if by != null and not t.structure and t.order == "" and t.target_id < 0 and not _on_enemy_throne(t) and t.role() != "healer" and t.kind != "king" and t.team != NEUTRAL and not by.structure:
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
	if u.carry != "":
		events.append({ "type": "drop", "what": u.carry, "pos": u.pos, "team": u.team })
	_raise_dead(u)


## A necromancer near a fallen hero raises it as a skeleton warrior of his own
## kingdom for a few turns (at most one every 4 seconds per necromancer).
func _raise_dead(dead: BUnit) -> void:
	if dead.structure or dead.kind == "king" or dead.data.get("raised", false):
		return
	for n: BUnit in units:
		if n.style() != "raise" or n.team == dead.team or n.team == NEUTRAL or n.hp <= 0.0:
			continue
		if n.pos.distance_to(dead.pos) > 3.0 or time < float(_raise_ready.get(n.id, 0.0)):
			continue
		_raise_ready[n.id] = time + 4.0
		var s := _spawn_hero(n.team, "soldier", dead.pos)
		s.data = s.data.duplicate()
		s.data["raised"] = true
		s.max_hp *= 0.6
		s.hp = s.max_hp
		s.expires_at = time + 15.0
		events.append({ "type": "raise", "id": s.id, "by": n.id, "pos": dead.pos })
		return


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
					dmg *= float(ab.get("structure_mult", 0.5))
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
	u.mine_timer += dt * (2.0 if u.has_effect("rage", time) else 1.0)
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
	if u.team == favoured_team():
		s *= SKY_BONUS_SPEED
	if u.carry == "crown":
		s *= 0.7
	return s


func _walk_toward(u: BUnit, goal: Vector2, dt: float, chasing: BUnit) -> void:
	var sp := _speed(u)
	if sp <= 0.0 or (u.team != NEUTRAL and u.budget <= 0.0):
		return
	if u.flying:
		_step_to(u, goal, sp * dt)
		return
	if u.path.is_empty() or time >= u.repath_at:
		u.repath_at = time + (0.6 if chasing != null else 1.5)
		var grid: AStarGrid2D = _grids[u.team]
		var from := _clamp_cell(u.cell())
		var to := _clamp_cell(Vector2i(roundi(goal.x), roundi(goal.y)))
		var ids := grid.get_id_path(_gm(u.team, from), _gm(u.team, to), true)
		u.path = []
		for i in range(1, ids.size()):
			u.path.append(Vector2(_gm(u.team, ids[i])))
		if not u.path.is_empty() and chasing == null and to == _gm(u.team, ids[ids.size() - 1]):
			u.path[u.path.size() - 1] = goal
		if u.path.is_empty():
			u.path = [goal] if _passable_for_team(u.team, to) else []
		# a hero rarely stands in the exact middle of its square: skip a first step
		# that would lead backwards (otherwise the rounding favours one kingdom)
		while u.path.size() >= 2 and u.pos.distance_to(u.path[1]) <= Vector2(u.path[0]).distance_to(u.path[1]) + 0.01:
			u.path.pop_front()
	if u.path.is_empty():
		return
	var left := sp * dt if u.team == NEUTRAL else minf(sp * dt, u.budget)
	while left > 0.0 and not u.path.is_empty():
		var nxt: Vector2 = u.path[0]
		var d := u.pos.distance_to(nxt)
		if d <= left:
			u.pos = nxt
			u.walked += d
			u.budget -= d
			u.still_since = time
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
	var step := minf(dist, v.length())
	if u.team != NEUTRAL:
		step = minf(step, maxf(0.0, u.budget))
	u.pos += v.normalized() * step
	u.walked += step
	u.budget -= step
	u.still_since = time


## Heroes push gently apart so a group does not melt into one spot. All pushes
## are worked out first and applied together, so the order of the units does not
## matter (pushing one pair after another favoured whichever kingdom came first).
func _separate() -> void:
	var movers := units.filter(func(u): return not u.structure and u.speed > 0.0 and u.kind != "king")
	var delta := {}
	for i in movers.size():
		for j in range(i + 1, movers.size()):
			var a: BUnit = movers[i]
			var b: BUnit = movers[j]
			var v: Vector2 = b.pos - a.pos
			var d := v.length()
			var min_d := (a.radius + b.radius) * 1.1
			if d < min_d:
				var push := (v.normalized() if d > 0.001 else Vector2(1, 0) * (1 if a.team == 0 else -1)) * (min_d - d) * 0.5
				delta[a] = delta.get(a, Vector2.ZERO) - push
				delta[b] = delta.get(b, Vector2.ZERO) + push
	for u: BUnit in delta:
		var np: Vector2 = u.pos + delta[u]
		if _passable_for(u, Vector2i(roundi(np.x), roundi(np.y))):
			u.pos = np


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
	c = _gm(team, c)
	return g.is_in_boundsv(c) and not g.is_point_solid(c)


## The Void's path grid is stored turned 180 degrees, so both kingdoms find
## exactly mirrored paths (A* breaks ties the same way in its own coordinates;
## without this one kingdom always picked the better of two equal roads).
func _gm(team: int, c: Vector2i) -> Vector2i:
	return Vector2i(w - 1 - c.x, h - 1 - c.y) if team == 1 else c


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
					g.set_point_solid(_gm(team, Vector2i(x, y)), true)
		_grids[team] = g


func _set_cell_open(c: Vector2i, _open: bool) -> void:
	for team in 3:
		var t := terrain_at(c)
		_grids[team].set_point_solid(_gm(team, c), t == Chess.Terrain.WALL or t == Chess.Terrain.WATER)


func _set_cell_blocked_for_enemies(team: int, c: Vector2i) -> void:
	for other in 3:
		if other != team:
			_grids[other].set_point_solid(_gm(other, c), true)


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
	u.budget = move_tiles(u) + 0.75
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


# ------------------------------------------------------------------ game modes

func _setup_mode() -> void:
	match mode:
		"crown":
			for team in 2:
				var seat: Vector2i = map["palaces"][team]["seat"]
				crowns.append({ "team": team, "pos": Vector2(seat), "home": Vector2(seat), "carrier": -1 })
		"runes":
			for c in map.get("runes", []):
				runes.append({ "id": runes.size(), "pos": Vector2(c), "home": Vector2(c), "carrier": -1, "back_at": 0.0 })


## A new turn: every hero gets its squares back, checkmate is judged, and the
## king steps to the safest square around him.
func _turn_start(turn_index: int) -> void:
	for u: BUnit in units:
		if not u.structure:
			# a little extra so a hero that stands a bit off the middle of its square still arrives
			u.budget = move_tiles(u) + 0.75
	if mode != "mate":
		return
	_update_mate()
	if turn_index > 0:
		var mated := [false, false]
		for team in 2:
			var zone := king_zone(team)
			mated[team] = not zone.is_empty() and mate_cells[team].size() >= zone.size()
		if mated[0] or mated[1]:
			winner = 2 if mated[0] and mated[1] else (1 if mated[0] else 0)
			events.append({ "type": "game_over", "winner": winner, "reason": "mate" })
			return
	for team in 2:
		var k := king(team)
		if k == null:
			continue
		var best := k.cell()
		var best_n := _threats_on(team, best) * 10 + 1
		for c in king_zone(team):
			var n: int = _threats_on(team, c) * 10 + (0 if c == k.cell() else 1)
			if n < best_n:
				best_n = n
				best = c
		if best != k.cell():
			k.order = "move"
			k.order_pos = Vector2(best)
			k.path = []


## The king's square and the free palace squares around it (the squares he could flee to).
func king_zone(team: int) -> Array:
	var k := king(team)
	if k == null:
		return []
	var fl: Rect2i = map["palaces"][team]["floor"]
	var res := []
	var flip := 1 if team == 0 else -1     # mirrored order, so both kings choose alike
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var c := k.cell() + Vector2i(dx, dy) * flip
			if fl.has_point(c) and terrain_at(c) != Chess.Terrain.WALL:
				res.append(c)
	return res


## Only heroes INSIDE the palace (through the broken gate) threaten the king.
func in_palace(team: int, c: Vector2i) -> bool:
	var fl: Rect2i = map["palaces"][team]["floor"]
	return fl.grow(1).has_point(c)


func _threats_on(king_team: int, c: Vector2i) -> int:
	var n := 0
	for e: BUnit in units:
		if e.team == king_team or e.team == NEUTRAL or e.structure or e.kind == "king" or e.role() in ["miner", "healer"]:
			continue
		if not in_palace(king_team, e.cell()):
			continue
		if e.pos.distance_to(Vector2(c)) <= clampf(e.range_, 1.5, 3.0) + 0.2:
			n += 1
	return n


func _update_mate() -> void:
	for team in 2:
		var cells := []
		for c in king_zone(team):
			if _threats_on(team, c) > 0:
				cells.append(c)
		mate_cells[team] = cells
		var k := king(team)
		var chk := k != null and cells.has(k.cell())
		if chk and not in_check[team]:
			events.append({ "type": "check", "team": team })
		in_check[team] = chk


func _win(team: int, reason: String) -> void:
	if winner >= 0:
		return
	winner = team
	events.append({ "type": "game_over", "winner": team, "reason": reason })


func _mode_tick(dt: float) -> void:
	match mode:
		"mate":
			_update_mate()
		"crown":
			for cr in crowns:
				var carrier := unit(cr["carrier"])
				if cr["carrier"] >= 0 and carrier == null:
					cr["carrier"] = -1        # the carrier fell: the crown lies where it fell
				if carrier != null:
					cr["pos"] = carrier.pos
					# home: at the own gate or inside the own palace
					var own: Dictionary = map["palaces"][carrier.team]
					if carrier.pos.distance_to(Vector2(own["spawn"])) <= 1.2 or (own["floor"] as Rect2i).grow(1).has_point(carrier.cell()):
						_win(carrier.team, "crown")
						return
					continue
				for u: BUnit in units:
					if u.team == NEUTRAL or u.structure or u.kind == "king" or u.carry != "" or u.pos.distance_to(cr["pos"]) > 0.6:
						continue
					if u.team != cr["team"]:
						cr["carrier"] = u.id
						u.carry = "crown"
						events.append({ "type": "crown_taken", "team": u.team, "id": u.id, "pos": u.pos })
						break
					elif Vector2(cr["pos"]) != Vector2(cr["home"]):
						cr["pos"] = cr["home"]
						events.append({ "type": "crown_back", "team": u.team, "pos": u.pos })
						break
		"throne":
			for team in 2:
				var seat := Vector2(map["palaces"][1 - team]["seat"])
				var sitters := false
				var guards := false
				for u: BUnit in units:
					if u.structure or u.team == NEUTRAL or u.pos.distance_to(seat) > 0.75:
						continue
					if u.team == team and u.kind != "king":
						sitters = true
					elif u.team != team:
						guards = true
				if sitters and not guards:
					var before := int(throne_time[team] / TURN)
					throne_time[team] += dt
					if int(throne_time[team] / TURN) != before:
						events.append({ "type": "throne", "team": team, "turns": int(throne_time[team] / TURN) })
					if throne_time[team] >= THRONE_TIME:
						_win(team, "throne")
						return
		"runes":
			for r in runes:
				var carrier := unit(r["carrier"])
				if r["carrier"] >= 0 and carrier == null:
					r["carrier"] = -1
				if carrier != null:
					r["pos"] = carrier.pos
					var k := king(carrier.team)
					if k != null and carrier.pos.distance_to(k.pos) <= 1.8:
						carrier.carry = ""
						r["carrier"] = -1
						r["pos"] = r["home"]
						r["back_at"] = time + RUNE_BACK
						rune_count[carrier.team] += 1
						events.append({ "type": "rune_home", "team": carrier.team, "count": rune_count[carrier.team], "pos": carrier.pos })
						if rune_count[carrier.team] >= RUNES_TO_WIN:
							_win(carrier.team, "runes")
							return
					continue
				if time < r["back_at"]:
					continue
				for u: BUnit in units:
					if u.team == NEUTRAL or u.structure or u.kind == "king" or u.carry != "" or u.pos.distance_to(r["pos"]) > 0.6:
						continue
					r["carrier"] = u.id
					u.carry = "rune"
					events.append({ "type": "rune_taken", "team": u.team, "id": u.id, "pos": u.pos })
					break
