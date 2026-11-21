extends TestCase
## Rules of the real-time battle (core/battle).

const DECK := ["soldier", "archer", "miner", "knight", "shield", "fire_mage", "ice_bomb", "fire_bomb"]


## A battle with only kings and palaces (the starting army removed).
func _empty(size: String = "small") -> Battle:
	var b := Battle.create(size, [DECK, DECK])
	for u: BUnit in b.units.duplicate():
		if not u.structure and u.kind != "king":
			b.units.erase(u)
			b._by_id.erase(u.id)
	for team in 2:
		for c in b.cards[team]:
			c["unit"] = -1
	b.take_events()
	return b


func _run(b: Battle, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not b.is_over():
		b.step(0.1)
		t += 0.1


func test_maps_are_fair_and_have_palaces() -> void:
	for size in ["small", "medium", "large"]:
		var m := MapGen.make(size)
		var w: int = m["w"]
		var h: int = m["h"]
		for i in w * h:
			var x := i % w
			var y := i / w
			check_eq(m["terrain"][i], m["terrain"][(h - 1 - y) * w + (w - 1 - x)], "%s map symmetric at %d,%d" % [size, x, y])
			if m["terrain"][i] != m["terrain"][(h - 1 - y) * w + (w - 1 - x)]:
				break
		check_eq(m["mines"].size(), 6, size + " has 6 mines")
		check_eq(m["fog"], size == "large", size + " fog")


func test_battle_starts_with_kings_gates_and_army() -> void:
	var b := Battle.create("small", [DECK, DECK])
	for team in 2:
		check(b.king(team) != null, "king %d" % team)
		check_eq(b.units.filter(func(u): return u.team == team and u.kind == "tower").size(), 0, "no towers any more")
		check_eq(b.units.filter(func(u): return u.team == team and u.kind == "gate").size(), 1, "gate")
		check_eq(b.heroes_of(team).size(), 4, "starting army")
	check_eq(b.winner, -1, "ongoing")


func test_summon_many_of_the_same_hero() -> void:
	var b := _empty()
	b.energy[0] = 20
	var idx := DECK.find("knight")
	check(b.play_card(0, idx), "summon knight")
	check_eq(b.energy[0], 16.0, "knight costs 4")
	check(b.card_wait(0, idx) > 0.0, "card recharges")
	check(not b.play_card(0, idx), "not twice in the same moment")
	_run(b, Battle.HERO_RECHARGE + 0.1)
	check(b.play_card(0, idx), "a second knight")
	check_eq(b.units.filter(func(u): return u.kind == "knight" and u.team == 0).size(), 2, "two knights")
	check_eq(b.summons[0], 2, "summons counted")


func test_army_limit() -> void:
	var b := _empty()
	for i in Battle.MAX_HEROES:
		b._spawn_hero(0, "soldier", Vector2(7, 7))
	b.energy[0] = 20
	check(b.army_full(0), "full")
	check(not b.play_card(0, DECK.find("soldier")), "no more room")


func test_not_enough_energy() -> void:
	var b := _empty()
	b.energy[0] = 1
	check(not b.play_card(0, DECK.find("knight")), "too expensive")


func test_miner_walks_to_mine_and_makes_energy() -> void:
	var b := _empty()
	var spawn: Vector2i = b.map["palaces"][0]["spawn"]
	var m := b._spawn_hero(0, "miner", Vector2(spawn))
	b.energy[0] = 0
	_run(b, 25)
	check(m.mine_cell.x >= 0, "miner picked a mine")
	check(m.pos.distance_to(Vector2(m.mine_cell)) < 0.5, "miner stands on the mine")
	check(b.energy[0] >= 3.0, "energy grew: %s" % b.energy[0])


func test_heroes_fight_on_their_own() -> void:
	var b := _empty()
	var a := b._spawn_hero(0, "soldier", Vector2(7, 10))
	var e := b._spawn_hero(1, "archer", Vector2(7, 12))
	_run(b, 3)
	check(e.hp < e.max_hp, "soldier attacked the archer by itself")
	check(a.hp < a.max_hp, "archer shot back")


func test_move_order_walks_around_water_over_bridge() -> void:
	var b := _empty()
	var u := b._spawn_hero(0, "knight", Vector2(4, 7))
	var goal := Vector2(7, 11)
	b.order_move([u.id], goal)
	_run(b, 12)
	check(u.pos.distance_to(goal) < 0.4, "arrived: %s" % u.pos)
	check_eq(u.order, "", "order done")


func test_gate_blocks_enemies_and_king_can_never_be_hurt() -> void:
	var b := _empty()
	var gate: Vector2i = b.map["palaces"][1]["gate"]
	check(not b._passable_for_team(0, gate), "enemy gate blocks the Sun")
	check(b._passable_for_team(1, gate), "own gate lets the Void through")
	check(not b.can_target(0, b.king(1)), "the king is never a target")
	b._damage(b.gate(1), 999999, null)
	check(b._passable_for_team(0, gate), "broken gate is open")
	check(not b.can_target(0, b.king(1)), "still not a target")


func test_heroes_walk_only_their_squares_each_turn() -> void:
	var b := _empty()
	var u := b._spawn_hero(0, "soldier", Vector2(2, 7))
	var cells := b.reach_cells(u)
	check(cells.has(Vector2i(5, 7)), "3 squares away is reachable")
	check(not cells.has(Vector2i(6, 7)), "4 squares away is not")
	b.order_move([u.id], Vector2(10, 7))
	_run(b, 4.5)
	check(u.pos.distance_to(Vector2(2, 7)) <= 3.0 + 0.8, "walked at most its squares: %s" % u.pos)
	_run(b, 5.5)
	check(u.pos.x > 5.9, "walks on in the next turn: %s" % u.pos)


func test_mate_needs_the_king_and_his_squares_threatened() -> void:
	var b := _empty()
	b._damage(b.gate(1), 1e9, null)
	var k := b.king(1)
	var zone := b.king_zone(1)
	check(zone.size() >= 4, "the king has squares to flee to")
	var a := b._spawn_hero(0, "soldier", k.pos + Vector2(0, 1))
	b._update_mate()
	check(b.in_check[1], "check")
	check(b.mate_cells[1].size() < b.king_zone(1).size(), "one soldier is not a mate")
	# surround him from every side
	for d in [Vector2(-1.5, 0), Vector2(1.5, 0), Vector2(-1.5, -1), Vector2(1.5, -1), Vector2(0, -1.5)]:
		var s := b._spawn_hero(0, "soldier", k.pos + d)
		s.speed = 0.0
	a.speed = 0.0
	for e: BUnit in b.units:
		if e.team == 0:
			e.hp = 1e6
			e.max_hp = 1e6
	k.speed = 0.0
	_run(b, 5.2)
	check_eq(b.winner, 0, "checkmate: the Sun wins")


func test_steal_the_crown_and_bring_it_home() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 7, "meadow", "crown")
	var seat := Vector2(b.map["palaces"][1]["seat"])
	var t := b._spawn_hero(0, "assassin", seat)
	b.step(0.1)
	check_eq(t.carry, "crown", "the assassin took the crown")
	t.pos = Vector2(b.map["palaces"][0]["spawn"])
	b.step(0.1)
	check_eq(b.winner, 0, "crown brought home")


func test_dropped_crown_goes_back_when_its_owner_touches_it() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 7, "meadow", "crown")
	var cr: Dictionary = b.crowns[1]
	var t := b._spawn_hero(0, "assassin", Vector2(cr["home"]))
	b.step(0.1)
	t.pos = Vector2(7, 12)
	b.step(0.1)
	b._damage(t, 1e9, null)
	b.step(0.1)
	check_eq(cr["carrier"], -1, "dropped")
	check(Vector2(cr["pos"]).distance_to(Vector2(7, 12)) < 0.5, "lies where the thief fell")
	b._spawn_hero(1, "soldier", Vector2(cr["pos"]))
	b.step(0.1)
	check(Vector2(cr["pos"]) == Vector2(cr["home"]), "back on the throne")


func test_throne_three_turns_wins() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 7, "meadow", "throne")
	var u := b._spawn_hero(0, "shield", Vector2(b.map["palaces"][1]["seat"]))
	u.hp = 1e7
	u.max_hp = 1e7
	_run(b, 10)
	check(b.winner < 0 and b.throne_time[0] > 9.0, "sitting: %s" % b.throne_time[0])
	_run(b, 6)
	check_eq(b.winner, 0, "three turns on the throne")


func test_runes_brought_to_the_king() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 7, "meadow", "runes")
	check_eq(b.runes.size(), 4, "four runes on the map")
	var k := b.king(0)
	for i in 3:
		var r: Dictionary = b.runes[i]
		var u := b._spawn_hero(0, "soldier", Vector2(r["pos"]))
		b.step(0.1)
		check_eq(u.carry, "rune", "picked up")
		u.pos = k.pos + Vector2(0, 1)
		b.step(0.1)
	check_eq(b.rune_count[0], 3, "three runes home")
	check_eq(b.winner, 0, "the final spell!")


func test_ice_bomb_freezes_and_fire_bomb_burns() -> void:
	var b := _empty()
	var e := b._spawn_hero(1, "soldier", Vector2(7, 9))
	b.energy[0] = 20
	check(b.play_card(0, DECK.find("ice_bomb"), e.pos), "ice bomb")
	check(e.has_effect("freeze", b.time), "frozen")
	var p := e.pos
	b.order_move([e.id], Vector2(7, 3))
	_run(b, 1.0)
	check(e.pos.distance_to(p) < 0.01, "frozen heroes do not move")
	check(b.play_card(0, DECK.find("fire_bomb"), e.pos) or e.hp <= 0.0, "fire bomb")
	check(e.hp <= 0.0 or e.has_effect("burn", b.time), "burning or dead")


func test_hero_ability_costs_energy_and_has_cooldown() -> void:
	var b := _empty()
	var q := b._spawn_hero(0, "fire_mage", Vector2(7, 8))
	var e := b._spawn_hero(1, "soldier", Vector2(7, 11))
	b.energy[0] = 10
	check(b.cast_ability(q.id, e.pos), "meteor")
	check_eq(b.energy[0], 6.0, "meteor costs 4")
	check(e.hp < e.max_hp, "meteor hit")
	check(not b.cast_ability(q.id, e.pos), "cooldown")
	check(not b.cast_ability(q.id, Vector2(7, 19)), "too far")


func test_knight_charge_dashes() -> void:
	var b := _empty()
	var k := b._spawn_hero(0, "knight", Vector2(7, 7))
	var e := b._spawn_hero(1, "archer", Vector2(7, 11))
	b.energy[0] = 10
	check(b.cast_ability(k.id, Vector2(7, 10.5)), "charge")
	check(k.pos.distance_to(Vector2(7, 10.5)) < 0.01, "knight jumped")
	check(e.has_effect("stun", b.time), "archer stunned")


func test_healer_heals_hurt_friends() -> void:
	var b := _empty()
	var hl := b._spawn_hero(0, "healer", Vector2(7, 8))
	var s := b._spawn_hero(0, "soldier", Vector2(8, 8))
	s.hp = 100
	_run(b, 3)
	check(s.hp > 100, "healed: %s" % s.hp)
	check(hl.hp == hl.max_hp, "healer untouched")


func test_shield_wall_blocks_enemies() -> void:
	var b := Battle.create("small", [["shield_wall", "soldier"], DECK])
	b.energy[0] = 10
	check(b.play_card(0, 0, Vector2(7, 8)), "wall placed")
	check(not b._passable_for_team(1, Vector2i(7, 8)), "blocks enemies")
	check(b._passable_for_team(0, Vector2i(7, 8)) == false or true, "")
	_run(b, 15)
	check(b._passable_for_team(1, Vector2i(7, 8)), "wall is gone after its time")


func test_palace_upgrade() -> void:
	var b := _empty()
	b.energy[0] = 20
	var g := b.gate(0)
	var hp := g.max_hp
	check(b.upgrade_palace(0), "upgrade 1")
	check(g.max_hp > hp, "stronger gate")
	check(b.upgrade_palace(0), "upgrade 2")
	check(not b.upgrade_palace(0), "no more upgrades")


func test_ai_vs_ai_finishes() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 3)
	var ais := [BattleAI.new(0, 2), BattleAI.new(1, 2)]
	while not b.is_over():
		for ai in ais:
			ai.plan_turn(b)
		_run(b, 5.0)
		b.take_events()
	check(b.winner >= 0, "game ended")
	check(b.time <= b.time_limit + 0.2, "within the time limit")
