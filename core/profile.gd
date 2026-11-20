class_name Profile
extends RefCounted
## The player's progress between battles (saved in the browser / user folder):
## gold, trophies, base buildings, decorations, hero levels and XP, the deck
## of 8 cards, chests waiting to be opened, and settings.

const SAVE_PATH := "user://profile.json"

var gold := 0
var trophies := 0
var wins := 0
var losses := 0
var buildings: Dictionary = {}     ## id -> level (0 = not built)
var decorations: Array = []        ## bought decoration ids
var heroes: Dictionary = {}        ## card id -> { level, xp }
var collection: Array = []         ## cards the player owns
var deck: Array = []               ## 8 card ids
var chests: Array = []             ## chest types waiting to be opened
var tutorial_done := false
var settings := { "music": 0.45, "sfx": 0.8, "map": "small" }


static func meta() -> Dictionary:
	return BattleData._load("res://data/meta.json")


static func new_profile() -> Profile:
	var p := Profile.new()
	var s: Dictionary = meta()["start"]
	p.gold = int(s["gold"])
	p.collection = s["collection"].duplicate()
	p.deck = s["deck"].duplicate()
	for b in meta()["buildings"]:
		p.buildings[b] = 1 if b in ["palace", "mine"] else 0
	for c in p.collection:
		p.heroes[c] = { "level": 1, "xp": 0 }
	return p


static func load_or_new(path: String = SAVE_PATH) -> Profile:
	if not FileAccess.file_exists(path):
		return new_profile()
	var d = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not d is Dictionary:
		return new_profile()
	var p := new_profile()
	for key in ["gold", "trophies", "wins", "losses"]:
		p.set(key, int(d.get(key, p.get(key))))
	for key in ["buildings", "heroes", "settings"]:
		var v: Dictionary = p.get(key)
		v.merge(d.get(key, {}), true)
	for key in ["decorations", "collection", "deck", "chests"]:
		if d.has(key) and d[key] is Array:
			p.set(key, d[key])
	p.tutorial_done = bool(d.get("tutorial_done", false))
	for k in p.heroes:
		p.heroes[k]["level"] = int(p.heroes[k]["level"])
		p.heroes[k]["xp"] = int(p.heroes[k]["xp"])
	return p


func save(path: String = SAVE_PATH) -> void:
	var d := { "gold": gold, "trophies": trophies, "wins": wins, "losses": losses, "buildings": buildings,
		"decorations": decorations, "heroes": heroes, "collection": collection, "deck": deck,
		"chests": chests, "tutorial_done": tutorial_done, "settings": settings }
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(d, "\t"))


# ------------------------------------------------------------------ arenas

func arena_index() -> int:
	var arenas: Array = meta()["arenas"]
	var idx := 0
	for i in arenas.size():
		if trophies >= int(arenas[i]["trophies"]):
			idx = i
	return idx


func arena() -> Dictionary:
	return meta()["arenas"][arena_index()]


# ------------------------------------------------------------------ heroes

func level_of(id: String) -> int:
	return int(heroes.get(id, {}).get("level", 1))


func levels() -> Dictionary:
	var out := {}
	for id in heroes:
		out[id] = level_of(id)
	return out


func xp_needed(id: String) -> int:
	return int(meta()["hero_level"]["xp"]) * level_of(id)


func upgrade_cost(id: String) -> int:
	return int(meta()["hero_level"]["gold"]) * level_of(id)


func can_upgrade(id: String) -> bool:
	return heroes.has(id) and level_of(id) < int(meta()["hero_level"]["max"]) \
		and int(heroes[id]["xp"]) >= xp_needed(id) and gold >= upgrade_cost(id)


func upgrade_hero(id: String) -> bool:
	if not can_upgrade(id):
		return false
	gold -= upgrade_cost(id)
	heroes[id]["xp"] = int(heroes[id]["xp"]) - xp_needed(id)
	heroes[id]["level"] = level_of(id) + 1
	return true


func add_xp(id: String, amount: int) -> void:
	if not heroes.has(id):
		heroes[id] = { "level": 1, "xp": 0 }
	heroes[id]["xp"] = int(heroes[id]["xp"]) + amount


# ------------------------------------------------------------------ deck

## Cards the player may put in the deck: owned and unlocked by a building.
func available_cards() -> Array:
	return collection.filter(func(c): return is_unlocked(c))


func is_unlocked(card: String) -> bool:
	for b in meta()["buildings"]:
		if card in meta()["buildings"][b].get("unlocks", []):
			return int(buildings.get(b, 0)) > 0
	return true


func set_deck_card(slot: int, card: String) -> bool:
	if slot < 0 or slot >= 8 or not available_cards().has(card):
		return false
	var old := deck.find(card)
	if old >= 0:
		deck[old] = deck[slot]   # swap places
	deck[slot] = card
	return true


# ------------------------------------------------------------------ base

func building_cost(id: String) -> int:
	var b: Dictionary = meta()["buildings"][id]
	return int(b["cost"]) * (int(buildings.get(id, 0)) + 1)


func can_build(id: String) -> bool:
	var b: Dictionary = meta()["buildings"].get(id, {})
	return not b.is_empty() and int(buildings.get(id, 0)) < int(b["max"]) \
		and gold >= building_cost(id) and trophies >= int(b.get("trophies", 0))


func build(id: String) -> bool:
	if not can_build(id):
		return false
	gold -= building_cost(id)
	buildings[id] = int(buildings.get(id, 0)) + 1
	# new heroes join the collection when their building is built
	for c in meta()["buildings"][id].get("unlocks", []):
		if not collection.has(c):
			collection.append(c)
			heroes[c] = { "level": 1, "xp": 0 }
	return true


func buy_decoration(id: String) -> bool:
	var d: Dictionary = meta()["decorations"].get(id, {})
	if d.is_empty() or decorations.has(id) or gold < int(d["cost"]):
		return false
	gold -= int(d["cost"])
	decorations.append(id)
	return true


## Extra start energy (mine level) and palace strength (palace level) in battles.
func start_energy_bonus() -> int:
	return (int(buildings.get("mine", 1)) - 1) * int(meta()["mine_bonus_energy"])


func palace_bonus() -> float:
	return (int(buildings.get("palace", 1)) - 1) * float(meta()["palace_bonus"])


# ------------------------------------------------------------------ rewards

## After a battle: gold, trophies, hero XP and maybe a chest. Returns what was given.
func apply_battle(result: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var key := "win" if result.get("won", false) else ("draw" if result.get("draw", false) else "loss")
	var r: Dictionary = meta()["rewards"][key]
	var k: float = meta()["rewards"]["size_bonus"].get(result.get("size", "small"), 1.0)
	var g := int(rng.randi_range(int(r["gold"][0]), int(r["gold"][1])) * k)
	if result.get("quit", false):
		g = 0
	var tr := int(r["trophies"])
	gold += g
	var before := trophies
	trophies = maxi(0, trophies + tr)
	var xp := int(int(r["xp"]) * k)
	for c in deck:
		if not BattleData.is_spell(c):
			add_xp(c, xp)
	var chest := ""
	if key == "win" and chests.size() < int(meta()["chest_slots"]):
		var roll := rng.randf()
		chest = "gold" if roll < 0.12 else ("silver" if roll < 0.4 else "wood")
		chests.append(chest)
	if key == "win":
		wins += 1
	elif key == "loss" and not result.get("quit", false):
		losses += 1
	return { "gold": g, "trophies": trophies - before, "xp": xp, "chest": chest,
		"new_arena": arena_index() > _arena_for(before) }


func _arena_for(t: int) -> int:
	var idx := 0
	var arenas: Array = meta()["arenas"]
	for i in arenas.size():
		if t >= int(arenas[i]["trophies"]):
			idx = i
	return idx


## Opens the first chest of a type: gold + XP for a few heroes (+ maybe a new card).
func open_chest(idx: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if idx < 0 or idx >= chests.size():
		return {}
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var type: String = chests[idx]
	chests.remove_at(idx)
	var c: Dictionary = meta()["chests"][type]
	var g := rng.randi_range(int(c["gold"][0]), int(c["gold"][1]))
	gold += g
	var pool := collection.filter(func(id): return not BattleData.is_spell(id) and id != "king")
	var xp_gifts := {}
	for i in pool.size():   # shuffle with the given rng so tests can repeat it
		var j := rng.randi_range(i, pool.size() - 1)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	for i in mini(int(c["heroes"]), pool.size()):
		var id: String = pool[i]
		var amount := rng.randi_range(int(c["xp"][0]), int(c["xp"][1])) / int(c["heroes"])
		add_xp(id, amount)
		xp_gifts[id] = int(xp_gifts.get(id, 0)) + amount
	return { "type": type, "gold": g, "xp": xp_gifts }


## The computer's deck for the current arena (stronger cards in later arenas).
func enemy_deck(rng: RandomNumberGenerator) -> Array:
	var a := arena_index()
	var pool := ["soldier", "archer", "knight", "shield"]
	if a >= 1: pool += ["fire_mage", "healer", "ice_witch", "queen"]
	if a >= 2: pool += ["assassin", "giant"]
	if a >= 3: pool += ["ballista", "dragon"]
	pool.shuffle()
	var deck_out := ["miner"]
	for c in pool:
		if deck_out.size() >= 6:
			break
		deck_out.append(c)
	var spells := ["ice_bomb", "fire_bomb", "heal_potion", "shield_wall"]
	spells.shuffle()
	for sp in spells:
		if deck_out.size() < 8:
			deck_out.append(sp)
	return deck_out
