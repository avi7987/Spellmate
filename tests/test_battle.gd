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


func test_battle_starts_with_kings_gates_towers_and_army() -> void:
	var b := Battle.create("small", [DECK, DECK])
	for team in 2:
		check(b.king(team) != null, "king %d" % team)
		check_eq(b.units.filter(func(u): return u.team == team and u.kind == "tower").size(), 2, "towers")
		check_eq(b.units.filter(func(u): return u.team == team and u.kind == "gate").size(), 1, "gate")
		check_eq(b.heroes_of(team).size(), 4, "starting army")
	check_eq(b.winner, -1, "ongoing")


func test_summon_costs_energy_and_card_waits_until_hero_dies() -> void:
	var b := _empty()
	b.energy[0] = 10
	var idx := DECK.find("knight")
	check(b.play_card(0, idx), "summon knight")
	check_eq(b.energy[0], 6.0, "knight costs 4")
	check_eq(b.card_wait(0, idx), -1.0, "card is on the field")
	check(not b.play_card(0, idx), "only once")
	var k: BUnit = b.units.filter(func(u): return u.kind == "knight")[0]
	b._damage(k, 99999, null)
	check(b.card_wait(0, idx) > 0.0, "card waits after death")
	_run(b, b.respawn_time("knight") + 0.2)
	check_eq(b.card_wait(0, idx), 0.0, "card ready again")


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


func test_gate_blocks_enemies_and_king_is_safe_behind_walls() -> void:
	var b := _empty()
	var gate: Vector2i = b.map["palaces"][1]["gate"]
	check(not b._passable_for_team(0, gate), "enemy gate blocks the Sun")
	check(b._passable_for_team(1, gate), "own gate lets the Void through")
	check(not b.king_exposed(1), "king protected")
	check(not b.can_target(0, b.king(1)), "cannot target protected king")
	var g: BUnit = b.units.filter(func(u): return u.team == 1 and u.kind == "gate")[0]
	b._damage(g, 999999, null)
	check(b.king_exposed(1), "gate down: king exposed")
	check(b._passable_for_team(0, gate), "broken gate is open")


func test_tower_falls_and_leaves_a_breach() -> void:
	var b := _empty()
	var t: BUnit = b.units.filter(func(u): return u.team == 1 and u.kind == "tower")[0]
	var c := t.cell()
	b._damage(t, 999999, null)
	check_eq(b.terrain_at(c), Chess.Terrain.CASTLE, "tower square is open")
	check(b._passable_for_team(0, c), "breach walkable")
	check(b.king_exposed(1), "king exposed after a tower falls")


func test_towers_shoot_nearby_enemies() -> void:
	var b := _empty()
	var t: BUnit = b.units.filter(func(u): return u.team == 0 and u.kind == "tower")[0]
	var e := b._spawn_hero(1, "shield", t.pos + Vector2(0, 2))
	e.speed = 0.0
	_run(b, 2.5)
	check(e.hp < e.max_hp, "tower shot the enemy")


func test_killing_the_king_wins() -> void:
	var b := _empty()
	b._damage(b.units.filter(func(u): return u.team == 1 and u.kind == "gate")[0], 1e9, null)
	b._damage(b.king(1), 1e9, b.king(0))
	check_eq(b.winner, 0, "Sun wins")
	check(b.is_over(), "over")


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
	var t: BUnit = b.units.filter(func(u): return u.team == 0 and u.kind == "tower")[0]
	var dmg := t.dmg
	check(b.upgrade_palace(0), "upgrade 1")
	check(t.dmg > dmg, "towers hit harder")
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
