extends TestCase
## The super powers and the energy system.


func _state(energy: int = 10) -> GameState:
	var s := GameState.empty()
	s.energy = [energy, energy]
	put(s, "a1", Chess.Kind.KING, Chess.WHITE)
	put(s, "l12", Chess.Kind.KING, Chess.BLACK)
	return s


func _sq(name: String) -> int:
	return Chess.parse_square(name)


func test_no_abilities_in_classic_mode() -> void:
	var s := GameState.new_game(false, 1)
	check(Rules.legal_abilities(s).is_empty(), "powers off")


func test_not_enough_energy() -> void:
	var s := _state(3)
	put(s, "d1", Chess.Kind.QUEEN, Chess.WHITE)
	put(s, "d4", Chess.Kind.ROOK, Chess.BLACK)
	check(find_action(s, "frost:d1>d4") == null, "frost costs 4")


func test_royal_decree_shield_blocks_attack() -> void:
	var s := _state()
	put(s, "b1", Chess.Kind.KNIGHT, Chess.WHITE)
	put(s, "b4", Chess.Kind.ROOK, Chess.BLACK)
	put(s, "b2", Chess.Kind.PAWN, Chess.WHITE)
	play(s, ["royal_decree:a1>a1"])
	check(find_action(s, "b4b1") == null, "a shielded unit cannot be attacked")
	check(s.is_shielded(s.piece_at(_sq("b2"))), "every neighbour is shielded")
	check_eq(int(s.energy[Chess.WHITE]), 7, "decree costs 3")


func test_frost_freezes_for_one_turn() -> void:
	var s := _state()
	put(s, "d1", Chess.Kind.QUEEN, Chess.WHITE)
	put(s, "d4", Chess.Kind.ROOK, Chess.BLACK)
	var near := put(s, "e5", Chess.Kind.PAWN, Chess.BLACK)
	play(s, ["frost:d1>d4"])
	check(s.is_frozen(near), "the frost storm also freezes enemies next to the target")
	check(Rules.legal_actions_from(s, _sq("d4")).is_empty(), "frozen rook cannot act")
	play(s, ["l12k12", "a1b1"])
	check(not Rules.legal_actions_from(s, _sq("d4")).is_empty(), "freeze expired")


func test_frost_respects_queen_range() -> void:
	var s := _state()
	put(s, "d1", Chess.Kind.QUEEN, Chess.WHITE)
	put(s, "d7", Chess.Kind.ROOK, Chess.BLACK)
	check(find_action(s, "frost:d1>d7") == null, "d7 is beyond the queen's range of 4")


func test_cooldown() -> void:
	var s := _state()
	put(s, "d1", Chess.Kind.QUEEN, Chess.WHITE)
	put(s, "d4", Chess.Kind.ROOK, Chess.BLACK)
	play(s, ["frost:d1>d4", "l12k12"])
	check(find_action(s, "frost:d1>d4") == null, "frost is on cooldown")
	check_eq(AbilityRegistry.by_id("frost").turns_until_ready(s, _sq("d1")), 2)


func test_stone_push() -> void:
	var s := _state()
	put(s, "d2", Chess.Kind.ROOK, Chess.WHITE)
	put(s, "d3", Chess.Kind.KNIGHT, Chess.BLACK)
	play(s, ["stone_push:d2>d3"])
	check_eq(s.piece_at(_sq("d5")).kind, Chess.Kind.KNIGHT, "shoved 2 squares to d5")
	check(s.is_frozen(s.piece_at(_sq("d5"))), "and stunned")


func test_stone_push_not_into_water() -> void:
	var s := _state()
	s.terrain[_sq("d4")] = Chess.Terrain.WATER
	put(s, "d2", Chess.Kind.ROOK, Chess.WHITE)
	put(s, "d3", Chess.Kind.KNIGHT, Chess.BLACK)
	check(find_action(s, "stone_push:d2>d3") == null)


func test_swap_same_colour_only() -> void:
	var s := _state()
	put(s, "c1", Chess.Kind.BISHOP, Chess.WHITE)
	put(s, "k9", Chess.Kind.ROOK, Chess.WHITE)   # same colour as c1
	put(s, "k8", Chess.Kind.ROOK, Chess.WHITE)   # other colour
	check(find_action(s, "swap:c1>k9") != null)
	check(find_action(s, "swap:c1>k8") == null)
	play(s, ["swap:c1>k9"])
	check_eq(s.piece_at(_sq("c1")).kind, Chess.Kind.ROOK)


func test_fire_blocks_movement() -> void:
	var s := _state()
	put(s, "d1", Chess.Kind.KNIGHT, Chess.WHITE)
	put(s, "c3", Chess.Kind.ROOK, Chess.WHITE)
	play(s, ["fire_breath:d1>c2", "l12k12"])
	check(s.is_lava(_sq("c2")))
	check(s.is_lava(_sq("b2")) and s.is_lava(_sq("c1")), "the fire spreads in a plus shape")
	check(find_action(s, "c3c1") == null, "cannot pass through fire")


func test_brace_adds_defense() -> void:
	var s := _state()
	put(s, "e5", Chess.Kind.PAWN, Chess.WHITE)
	var buddy := put(s, "f5", Chess.Kind.PAWN, Chess.WHITE)
	put(s, "e7", Chess.Kind.ROOK, Chess.BLACK)
	play(s, ["brace:e5>e5"])
	check(s.is_braced(buddy), "neighbouring soldiers brace too")
	# 60 + 0 (rook atk) - 25 brace - 10 phalanx (f5) = 25
	check_eq(Combat.chance(s, _sq("e7"), _sq("e5")), 25)


func test_toil_gives_energy() -> void:
	var s := _state(4)
	put(s, "c2", Chess.Kind.MINER, Chess.WHITE)
	play(s, ["toil:c2>c2"])
	check_eq(int(s.energy[Chess.WHITE]), 7)
