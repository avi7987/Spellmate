class_name Combat
extends RefCounted
## Battles: when a unit moves onto an enemy, they fight. The attacker's chance
## to win starts at combat.base_attack (data/balance.json) and is changed by
## each unit's battle bonus, its special trait, terrain and magic effects.
## The loser dies - except a Bishop (phase trait), who slips back home when
## its attack fails.

## Returns { "chance": int (percent the attacker wins), "lines": [[text_key, delta], ...] }
## The lines explain the chance, for the battle panel.
static func odds(state: GameState, from: int, to: int) -> Dictionary:
	var a := state.piece_at(from)
	var d := state.piece_at(to)
	var lines := []
	var chance := Balance.combat("base_attack")
	lines.append(["base", chance])
	if a == null or d == null:
		return { "chance": chance, "lines": lines }
	var atk := UnitData.attack_bonus(a.kind)
	if atk != 0:
		lines.append(["atk_" + UnitData.trait_id(a.kind), atk])
	var def := -UnitData.defense_bonus(d.kind)
	if def != 0:
		lines.append(["def_" + UnitData.trait_id(d.kind), def])
	if UnitData.trait_id(d.kind) == "phalanx":
		var allies := 0
		for o in Chess.KING_OFFSETS:
			var f: int = Chess.file_of(to) + o[0]
			var r: int = Chess.rank_of(to) + o[1]
			if Chess.on_board(f, r):
				var n := state.piece_at(Chess.sq(f, r))
				if n != null and n.color == d.color and n.kind == d.kind:
					allies += 1
		var bonus := mini(allies * Balance.combat("phalanx_per_ally"), Balance.combat("phalanx_max"))
		if bonus > 0:
			lines.append(["phalanx", -bonus])
	match state.terrain_at(from):
		Chess.Terrain.HILL:
			lines.append(["hill", Balance.combat("hill_attack")])
	match state.terrain_at(to):
		Chess.Terrain.FOREST:
			lines.append(["forest", -Balance.combat("forest_defense")])
		Chess.Terrain.CASTLE:
			# Only the defender's own castle helps it (Sun castle is on rank 0).
			var home := Chess.rank_of(to) < Chess.H / 2
			if (d.color == Chess.WHITE) == home:
				lines.append(["castle", -Balance.combat("castle_defense")])
	if state.is_braced(d):
		lines.append(["brace", -Balance.combat("brace_defense")])
	if state.is_frozen(d):
		lines.append(["frozen", Balance.combat("frozen_defender")])
	var total := 0
	for l in lines:
		total += int(l[1])
	return { "chance": clampi(total, Balance.combat("min"), Balance.combat("max")), "lines": lines }


static func chance(state: GameState, from: int, to: int) -> int:
	return int(odds(state, from, to)["chance"])
