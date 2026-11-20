extends TestCase
## Worlds (biomes): special ground, shrines, treasure chests, neutral monsters.

const DECK := ["soldier", "archer", "miner", "knight", "shield", "fire_mage", "ice_bomb", "fire_bomb"]


func _clear(b: Battle) -> void:
	for u: BUnit in b.units.duplicate():
		if not u.structure and u.kind != "king" and u.team != Battle.NEUTRAL:
			b.units.erase(u)
			b._by_id.erase(u.id)
	b.take_events()


func _run(b: Battle, seconds: float) -> void:
	var t := 0.0
	while t < seconds and not b.is_over():
		b.step(0.1)
		t += 0.1


func _find(b: Battle, kind: int) -> Vector2i:
	for i in b.w * b.h:
		if b.map["terrain"][i] == kind:
			return Vector2i(i % b.w, i / b.w)
	return Vector2i(-1, -1)


func test_every_world_makes_a_fair_playable_map() -> void:
	for biome in BattleData.biome_ids():
		for size in ["small", "medium", "large"]:
			var m := MapGen.make(size, 5, biome)
			var w: int = m["w"]
			var h: int = m["h"]
			var ok := true
			for i in w * h:
				if m["terrain"][i] != m["terrain"][(h - 1 - i / w) * w + (w - 1 - i % w)]:
					ok = false
			check(ok, "%s %s symmetric" % [biome, size])
			check_eq(m["shrines"].size(), 6, "6 shrines")
			check_eq(m["camps"].size(), 2, "2 monster camps")
			var cx := (w - 1) / 2
			check(MapGen._all_reachable(m["terrain"], w, h, Vector2i(cx, 5), [Vector2i(w - 1 - cx, h - 6)] + m["mines"]), "%s %s roads open" % [biome, size])


func test_lava_burns_and_candy_gives_rage() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 3, "fire")
	_clear(b)
	var c := _find(b, Chess.Terrain.SPECIAL)
	check(c.x >= 0, "lava exists")
	var u := b._spawn_hero(0, "shield", Vector2(c))
	u.speed = 0.0
	_run(b, 1.0)
	check(u.hp < u.max_hp, "lava burns")
	var b2 := Battle.create("small", [DECK, DECK], [{}, {}], 3, "candy")
	_clear(b2)
	var c2 := _find(b2, Chess.Terrain.SPECIAL)
	var u2 := b2._spawn_hero(0, "shield", Vector2(c2))
	u2.speed = 0.0
	_run(b2, 0.3)
	check(u2.has_effect("rage", b2.time), "sugar rage")


func test_mud_slows() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 3, "swamp")
	var c := _find(b, Chess.Terrain.SPECIAL)
	var u := b._spawn_hero(0, "knight", Vector2(c))
	check(b._speed(u) < u.speed, "mud is slow")


func test_monster_guards_camp_and_gives_reward() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 3, "ice")
	var monsters := b.units.filter(func(u): return u.team == Battle.NEUTRAL)
	check_eq(monsters.size(), 2, "two monsters")
	check_eq(monsters[0].kind, "yeti", "ice world has yetis")
	_clear(b)
	var m: BUnit = b.units.filter(func(u): return u.team == Battle.NEUTRAL)[0]
	var hero := b._spawn_hero(0, "shield", m.home + Vector2(1.2, 0))
	hero.speed = 0.0
	_run(b, 2.0)
	check(hero.hp < hero.max_hp, "monster attacked the hero")
	b.energy[0] = 0
	var g: int = b.bonus_gold[0]
	b._damage(m, 1e9, hero)
	check(b.energy[0] >= 6.0, "energy reward")
	check(b.bonus_gold[0] > g, "gold reward")


func test_monster_goes_home() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 3, "meadow")
	_clear(b)
	var m: BUnit = b.units.filter(func(u): return u.team == Battle.NEUTRAL)[0]
	m.pos = m.home + Vector2(4, 0)
	_run(b, 5.0)
	check(m.pos.distance_to(m.home) < 0.5, "back home")


func test_treasure_chests_appear_in_pairs_and_give_energy() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 3, "desert")
	_clear(b)
	b._spawn_treasure()
	check_eq(b.pickups.size(), 2, "a fair pair")
	var p: Dictionary = b.pickups[0]
	b.energy[0] = 0
	b._spawn_hero(0, "soldier", p["pos"]).speed = 0.0
	_run(b, 0.2)
	check_eq(b.pickups.size(), 1, "picked up")
	check(b.energy[0] >= 4.0, "energy from treasure")


func test_energy_well_and_healing_spring() -> void:
	var b := Battle.create("small", [DECK, DECK], [{}, {}], 3, "meadow")
	_clear(b)
	var well: Dictionary = b.map["shrines"].filter(func(s): return s["type"] == "energy")[0]
	var spring: Dictionary = b.map["shrines"].filter(func(s): return s["type"] == "heal")[0]
	b._spawn_hero(0, "shield", Vector2(well["pos"])).speed = 0.0
	var hurt := b._spawn_hero(0, "shield", Vector2(spring["pos"]))
	hurt.speed = 0.0
	hurt.hp = 300
	b.energy[0] = 0
	_run(b, 3.5)
	check(b.energy[0] >= 1.0, "the well gives energy")
	check(hurt.hp > 300, "the spring heals")
