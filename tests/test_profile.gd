extends TestCase
## Progress between battles: base buildings, hero levels, deck, rewards, chests.


func _rng() -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = 42
	return r


func test_new_profile_has_a_playable_deck() -> void:
	var p := Profile.new_profile()
	check_eq(p.deck.size(), 8, "8 cards")
	check(p.deck.has("miner"), "a miner to make energy")
	for c in p.deck:
		check(p.available_cards().has(c), "deck card available: " + c)


func test_building_costs_gold_and_unlocks_heroes() -> void:
	var p := Profile.new_profile()
	p.gold = 100
	check(not p.build("mage_tower"), "too poor")
	p.gold = 1000
	check(not p.available_cards().has("queen"), "queen locked")
	check(p.build("mage_tower"), "built")
	check_eq(p.gold, 700, "paid 300")
	check(p.available_cards().has("queen"), "queen unlocked")
	check(not p.build("mage_tower"), "only once")


func test_trophies_needed_for_some_buildings() -> void:
	var p := Profile.new_profile()
	p.gold = 5000
	check(not p.can_build("dragon_roost"), "needs trophies")
	p.trophies = 600
	check(p.build("dragon_roost"), "now ok")


func test_palace_and_mine_levels_give_battle_bonuses() -> void:
	var p := Profile.new_profile()
	p.gold = 5000
	check_eq(p.start_energy_bonus(), 0, "no bonus at level 1")
	p.build("mine")
	p.build("palace")
	check_eq(p.start_energy_bonus(), 1, "mine level 2")
	check(p.palace_bonus() > 0.0, "palace level 2")
	var b := Battle.create("small", [p.deck, p.deck])
	var k := b.king(0).max_hp
	b.apply_bonuses(0, p.palace_bonus(), p.start_energy_bonus())
	check(b.king(0).max_hp > k, "stronger king")


func test_hero_upgrade_needs_xp_and_gold() -> void:
	var p := Profile.new_profile()
	p.gold = 1000
	check(not p.upgrade_hero("archer"), "no xp yet")
	p.add_xp("archer", p.xp_needed("archer"))
	check(p.upgrade_hero("archer"), "upgraded")
	check_eq(p.level_of("archer"), 2, "level 2")
	check_eq(p.levels()["archer"], 2, "levels for battle")


func test_win_gives_gold_trophies_xp_and_chest() -> void:
	var p := Profile.new_profile()
	var r := p.apply_battle({ "won": true, "size": "small" }, _rng())
	check(r["gold"] > 0, "gold")
	check_eq(p.trophies, 30, "trophies")
	check(r["chest"] != "", "chest")
	check_eq(p.chests.size(), 1, "chest saved")
	check(int(p.heroes["soldier"]["xp"]) > 0, "deck heroes got xp")
	var t := p.trophies
	p.apply_battle({ "won": false, "size": "small" }, _rng())
	check(p.trophies < t, "loss takes trophies")


func test_chest_slots_are_limited() -> void:
	var p := Profile.new_profile()
	for i in 6:
		p.apply_battle({ "won": true, "size": "small" }, _rng())
	check_eq(p.chests.size(), 4, "max 4 chests")


func test_open_chest() -> void:
	var p := Profile.new_profile()
	p.chests = ["silver"]
	var g := p.gold
	var r := p.open_chest(0, _rng())
	check(p.gold > g, "gold from chest")
	check_eq(r["xp"].size(), 3, "3 different heroes get xp")
	check(p.chests.is_empty(), "chest gone")


func test_deck_swap() -> void:
	var p := Profile.new_profile()
	p.gold = 1000
	p.build("mage_tower")
	check(p.set_deck_card(0, "queen"), "queen in slot 0")
	check_eq(p.deck[0], "queen", "slot 0")
	check(not p.deck.has("soldier"), "soldier out")
	check(p.set_deck_card(1, "queen"), "move queen to slot 1")
	check_eq(p.deck.count("queen"), 1, "no duplicates")
	check(not p.set_deck_card(2, "dragon"), "locked card refused")


func test_save_and_load() -> void:
	var path := "user://test_profile.json"
	var p := Profile.new_profile()
	p.gold = 777
	p.trophies = 123
	p.chests = ["gold"]
	p.save(path)
	var q := Profile.load_or_new(path)
	check_eq(q.gold, 777, "gold")
	check_eq(q.trophies, 123, "trophies")
	check_eq(q.chests, ["gold"], "chests")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_enemy_deck_is_valid() -> void:
	var p := Profile.new_profile()
	for t in [0, 500, 1500]:
		p.trophies = t
		var d := p.enemy_deck(_rng())
		check_eq(d.size(), 8, "8 cards")
		check(d.has("miner"), "computer has a miner")
		for c in d:
			check(not BattleData.card(c).is_empty(), "known card " + c)


func test_daily_quests() -> void:
	var p := Profile.new_profile()
	p.refresh_quests("2026-01-01", _rng())
	check_eq(p.quests.size(), 3, "3 quests")
	var ids := p.quests.map(func(q): return q["id"])
	check_eq(ids.size(), 3, "different quests")
	for q in p.quests:
		check(Profile.quest_text(q) != "", "has text")
	# finish all quests with a huge result
	for i in 3:
		p.apply_battle({ "won": true, "size": "small", "world": ["meadow", "fire", "ice"][i], "spells": 9, "summons": 30,
			"monsters": 3, "treasures": 5, "structures": 5, "powers": 9 }, _rng())
	p.quests_day = "2026-01-01"   # (apply_battle refreshes for the real date)
	check(p.quests_ready() >= 1, "quests done")
	var g := p.gold
	var got := p.claim_quest(0)
	check(got > 0 and p.gold == g + got, "reward")
	check_eq(p.claim_quest(0), 0, "only once")
	p.refresh_quests("2026-01-02", _rng())
	check(not p.quests[0]["claimed"], "new day, new quests")


func test_new_cards_of_built_buildings_join_old_saves() -> void:
	var p := Profile.new_profile()
	p.gold = 9999
	p.build("mage_tower")
	p.collection.erase("druid")
	var path := "user://test_profile_migrate.json"
	p.save(path)
	var q := Profile.load_or_new(path)
	check(q.collection.has("druid"), "the druid came with the mage tower")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
