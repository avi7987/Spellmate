extends TestCase
## Day and night, the eclipse, two powers per hero, and each hero's own way of fighting.

const DECK := ["soldier", "archer", "miner", "knight", "shield", "fire_mage", "ice_bomb", "fire_bomb"]


func _empty() -> Battle:
	var b := Battle.create("small", [DECK, DECK])
	b.sky_offset = 0
	for u: BUnit in b.units.duplicate():
		if not u.structure and u.kind != "king":
			b.units.erase(u)
			b._by_id.erase(u.id)
	b.take_events()
	return b


func _run(b: Battle, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not b.is_over():
		b.step(0.05)
		t += 0.05


func test_sky_cycle_and_eclipse() -> void:
	check_eq(Battle.sky_of_turn(0), "day", "turn 1 day")
	check_eq(Battle.sky_of_turn(2), "eclipse", "turn 3 eclipse")
	check_eq(Battle.sky_of_turn(3), "night", "turn 4 night")
	check_eq(Battle.sky_of_turn(5), "eclipse", "an eclipse after the nights too (fair)")
	check_eq(Battle.sky_of_turn(6), "day", "cycle repeats")
	var b := _empty()
	var q := b._spawn_hero(0, "queen", Vector2(7, 7))
	q.ability_ready_at = 999.0
	_run(b, Battle.TURN * 2 + 0.2)
	check_eq(b.sky(), "eclipse", "eclipse now")
	check(q.ability_ready_at <= b.time, "eclipse recharged the power")


func test_favoured_kingdom_hits_harder() -> void:
	var b := _empty()
	var a := b._spawn_hero(0, "soldier", Vector2(7, 7))
	var e := b._spawn_hero(1, "shield", Vector2(7, 8))
	e.speed = 0.0
	b._hit(a, e)
	var day_dmg := e.max_hp - e.hp
	b.time = Battle.TURN * 2 + 0.1   # night
	e.hp = e.max_hp
	a.attack_ready_at = 0.0
	b._hit(a, e)
	var night_dmg := e.max_hp - e.hp
	check(day_dmg > night_dmg * 1.2, "sun is stronger by day: %d vs %d" % [day_dmg, night_dmg])


func test_second_power_from_loadout() -> void:
	var b := _empty()
	var k := b._spawn_hero(0, "knight", Vector2(7, 7))
	check_eq(b.ability_of(k)["id"], "charge", "first power")
	b.loadout[0]["knight"] = 1
	check_eq(b.ability_of(k)["id"], "battle_cry", "second power")


func test_knight_momentum() -> void:
	var b := _empty()
	var k := b._spawn_hero(0, "knight", Vector2(7, 7))
	var e := b._spawn_hero(1, "shield", Vector2(7, 8))
	b.time = Battle.TURN * 2 + 0.1   # eclipse: no sky bonus
	k.walked = 0.0
	b._hit(k, e)
	var plain := e.max_hp - e.hp
	e.hp = e.max_hp
	k.attack_ready_at = 0.0
	k.walked = 4.0
	b._hit(k, e)
	check(e.max_hp - e.hp > plain * 1.8, "charge doubles the hit")
	check(e.has_effect("stun", b.time), "and stuns")


func test_bone_guard_taunts() -> void:
	var b := _empty()
	var s := b._spawn_hero(0, "shield", Vector2(7, 8))
	b._spawn_hero(0, "archer", Vector2(7, 7.5))
	var enemy := b._spawn_hero(1, "soldier", Vector2(7, 9.5))
	check_eq(b._nearest_enemy(enemy, 5.0), s, "enemies must attack the bone guard")


func test_assassin_hides_until_it_strikes() -> void:
	var b := _empty()
	var a := b._spawn_hero(1, "assassin", Vector2(7, 10))
	var archer := b._spawn_hero(0, "archer", Vector2(7, 7))
	check(b._nearest_enemy(archer, 6.0) == null, "hidden from afar")
	b._hit(a, archer)
	check_eq(b._nearest_enemy(archer, 6.0), a, "seen after attacking")


func test_giant_knocks_back_and_queen_chains() -> void:
	var b := _empty()
	var g := b._spawn_hero(0, "giant", Vector2(7, 7))
	var e := b._spawn_hero(1, "soldier", Vector2(7, 8))
	var before := e.pos
	b._hit(g, e)
	check(e.pos.distance_to(g.pos) > before.distance_to(g.pos) + 0.5, "pushed away")
	var q := b._spawn_hero(0, "queen", Vector2(3, 7))
	var t1 := b._spawn_hero(1, "archer", Vector2(3, 9))
	var t2 := b._spawn_hero(1, "archer", Vector2(4, 10))
	b._hit(q, t1)
	check(t2.hp < t2.max_hp, "the bolt jumped")


func test_ballista_must_stand_still() -> void:
	var b := _empty()
	var bl := b._spawn_hero(0, "ballista", Vector2(7, 7))
	var e := b._spawn_hero(1, "shield", Vector2(7, 12))
	bl.still_since = b.time
	b._hit(bl, e)
	check_eq(e.hp, e.max_hp, "no shot right after moving")
	b.time += 1.2
	b._hit(bl, e)
	check(e.hp < e.max_hp, "shoots after setting up")


func test_soldiers_fight_better_together() -> void:
	var b := _empty()
	b.time = Battle.TURN * 4 + 0.1
	var s1 := b._spawn_hero(0, "soldier", Vector2(7, 7))
	var e := b._spawn_hero(1, "shield", Vector2(7, 8))
	b._hit(s1, e)
	var alone := e.max_hp - e.hp
	e.hp = e.max_hp
	s1.attack_ready_at = 0.0
	b._spawn_hero(0, "soldier", Vector2(6.5, 7))
	b._spawn_hero(0, "soldier", Vector2(7.5, 7))
	b._hit(s1, e)
	check(e.max_hp - e.hp > alone * 1.25, "pack bonus")


func test_bard_song_makes_friends_attack_faster() -> void:
	var b := _empty()
	var s := b._spawn_hero(0, "soldier", Vector2(7, 7))
	var e := b._spawn_hero(1, "shield", Vector2(7, 8))
	b._hit(s, e)
	var plain := s.attack_ready_at - b.time
	s.attack_ready_at = 0.0
	b._spawn_hero(0, "bard", Vector2(6, 7))
	b._hit(s, e)
	check(s.attack_ready_at - b.time < plain - 0.05, "faster with a bard: %s vs %s" % [s.attack_ready_at - b.time, plain])


func test_golem_shrugs_off_arrows() -> void:
	var b := _empty()
	var g := b._spawn_hero(0, "golem", Vector2(7, 7))
	var a := b._spawn_hero(1, "archer", Vector2(7, 11))
	b._damage(g, 100.0, a)
	check(absf(g.max_hp - g.hp - 50.0) < 0.01, "half damage from far: %s" % (g.max_hp - g.hp))


func test_necromancer_raises_the_fallen() -> void:
	var b := _empty()
	var n := b._spawn_hero(0, "necromancer", Vector2(7, 7))
	var e := b._spawn_hero(1, "archer", Vector2(7, 9))
	var before := b.heroes_of(0).size()
	b._damage(e, 1e6, n)
	check_eq(b.heroes_of(0).size(), before + 1, "a skeleton rose for the Sun")
	var s: BUnit = b.heroes_of(0).back()
	check(s.expires_at > b.time, "only for a while")


func test_earthquake_hits_gates_hard() -> void:
	var b := Battle.create("small", [["earthquake", "soldier"], ["soldier"]])
	b.energy[0] = 20
	var g := b.gate(1)
	check(b.play_card(0, 0, g.pos), "earthquake")
	check_eq(g.max_hp - g.hp, 160.0 * 3.0, "three times on the gate")
