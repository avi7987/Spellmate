class_name Combat
extends RefCounted
## Fights between units (and against gates and towers).
##
## The attacker strikes first: damage = attack - armour (at least 1), changed by
## terrain, traits and a bit of luck (the dice, +-combat.variance %). If the
## defender survives and can reach the attacker, it hits back with
## combat.counter_factor % of its damage. Units at 0 health die.
## All numbers are in data/balance.json and data/units.json.

const SUPPORT := ["archer", "healer", "ice_witch", "fire_mage", "ballista", "queen", "miner"]


## Raw damage (before luck) `attacker` would deal to the target on square `to`
## if it stood on `at`.
static func base_damage(state: GameState, attacker: Piece, at: int, to: int) -> int:
	var dmg := float(UnitData.attack(attacker.kind))
	var tr := UnitData.trait_id(attacker.kind)
	if tr == "charge" and attacker.steps_taken >= 3:
		dmg += Balance.combat("charge_bonus")
	if state.terrain_at(at) == Chess.Terrain.HILL:
		dmg *= 1.0 + Balance.combat("hill_attack") / 100.0
	var target := state.piece_at(to)
	var armour := 0
	if target != null:
		armour = UnitData.armor(target.kind)
		match state.terrain_at(to):
			Chess.Terrain.FOREST:
				armour += Balance.combat("forest_defense")
			Chess.Terrain.CASTLE:
				if state.palace_owner(to) == target.color:
					armour += Balance.combat("castle_defense")
		if state.is_braced(target):
			armour += Balance.combat("brace_defense")
		if state.is_frozen(target):
			armour += Balance.combat("frozen_defense")
		if UnitData.trait_id(target.kind) == "phalanx":
			for o in Chess.KING_OFFSETS:
				var f: int = Chess.file_of(to) + o[0]
				var r: int = Chess.rank_of(to) + o[1]
				if Chess.on_board(f, r):
					var n := state.piece_at(Chess.sq(f, r))
					if n != null and n.color == target.color and n.kind == target.kind:
						armour += Balance.combat("phalanx_per_ally")
		if tr == "shadow" and SUPPORT.has(Chess.KIND_NAMES[target.kind]):
			dmg *= 1.0 + Balance.combat("backstab") / 100.0
	else:
		var st := state.structure_at(to)
		armour = int(UnitData.structure(st.get("kind", "gate")).get("def", 2))
		if tr == "siege" or tr == "artillery":
			dmg *= Balance.combat("siege_factor") / 100.0
	return maxi(Balance.combat("min_damage"), roundi(dmg) - maxi(0, armour))


## Can the defender on `to` hit back at a unit standing on `at`?
static func can_counter(state: GameState, defender: Piece, to: int, at: int) -> bool:
	if defender == null or state.is_frozen(defender):
		return false
	if UnitData.trait_id(defender.kind) == "artillery":
		return false
	return Chess.distance(to, at) <= UnitData.attack_range(defender.kind)


## Expected result of an attack (no luck), for the preview panel:
## { damage, counter, kills, dies }
static func preview(state: GameState, from: int, to: int) -> Dictionary:
	var a := state.piece_at(from)
	var d := state.piece_at(to)
	var dmg := base_damage(state, a, from, to)
	var target_hp: int = d.hp if d != null else int(state.structure_at(to).get("hp", 0))
	var kills := dmg >= target_hp
	var counter := 0
	if d != null and not kills and can_counter(state, d, to, from):
		counter = maxi(1, roundi(base_damage(state, d, to, from) * Balance.combat("counter_factor") / 100.0))
	return { "damage": dmg, "counter": counter, "kills": kills, "dies": counter >= a.hp }


## Rolls luck on a damage number.
static func roll(state: GameState, dmg: int) -> int:
	var v := Balance.combat("variance")
	var factor := 1.0 + (state.roll_d100() - 50) / 50.0 * v / 100.0
	return maxi(1, roundi(dmg * factor))
