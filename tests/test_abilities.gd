extends TestCase
## The Spellmate super powers and the energy system.


func _state(fen: String, energy: int = 10) -> GameState:
	var s := GameState.from_fen(fen)
	s.abilities_enabled = true
	s.energy = [energy, energy]
	return s


func _sq(name: String) -> int:
	return Chess.parse_square(name)


func test_energy_gain_per_turn_and_capture() -> void:
	var s := GameState.new_game(true)
	check_eq(s.energy, [1, 0], "white starts its first turn with 1")
	play(s, ["e2e4"])
	check_eq(s.energy, [1, 1])
	play(s, ["d7d5", "e4d5"])  # white captures: +1, black gets turn +1
	check_eq(s.energy, [3, 2])


func test_no_abilities_in_classic_mode() -> void:
	var s := GameState.new_game(false)
	check(Rules.legal_abilities(s).is_empty(), "classic mode has no abilities")


func test_not_enough_energy() -> void:
	var s := _state("4k3/8/8/8/8/8/8/3QK3 w - - 0 1", 3)
	check(Rules.legal_abilities(s).filter(func(a): return a.ability_id == "frost").is_empty(),
		"frost costs 4")


func test_royal_decree_shield_blocks_capture() -> void:
	var s := _state("4k3/8/8/8/8/8/3r4/3NK3 b - - 0 1")
	# Black rook on d2 attacks the knight on d1... first let white shield it:
	s.side_to_move = Chess.WHITE
	play(s, ["royal_decree:e1>d1"])
	check(find_action(s, "d2d1") == null, "shielded knight cannot be captured")
	check_eq(int(s.energy[Chess.WHITE]), 7, "decree costs 3")
	play(s, ["e8f8", "e1f1"])  # shield ends at white's next turn
	play(s, ["f8e8"])
	s.side_to_move = Chess.BLACK
	check(find_action(s, "d2d1") != null, "shield expired")


func test_frost_freezes_for_one_turn() -> void:
	var s := _state("3rk3/8/8/8/8/8/8/3QK3 w - - 0 1")
	play(s, ["frost:d1>d8"])
	check(Rules.legal_actions_from(s, _sq("d8")).is_empty(), "frozen rook cannot act")
	play(s, ["e8f7", "e1f1"])
	check(not Rules.legal_actions_from(s, _sq("d8")).is_empty(), "freeze expired")


func test_frost_cannot_target_king() -> void:
	var s := _state("3k4/8/8/8/8/8/8/3QK3 w - - 0 1")
	check(find_action(s, "frost:d1>d8") == null, "kings cannot be frozen")


func test_cooldown() -> void:
	var s := _state("3rk3/8/8/8/8/8/8/3QK3 w - - 0 1")
	play(s, ["frost:d1>d8", "e8f7"])
	s.energy = [10, 10]
	check(Rules.legal_abilities(s).filter(func(a): return a.ability_id == "frost").is_empty(),
		"frost is on cooldown")
	var ab := AbilityRegistry.by_id("frost")
	check_eq(ab.turns_until_ready(s, _sq("d1")), 2)


func test_stone_push() -> void:
	var s := _state("4k3/8/8/8/8/3n4/3R4/K7 w - - 0 1")
	play(s, ["stone_push:d2>d3"])
	check_eq(s.piece_at(_sq("d4")).kind, Chess.Kind.KNIGHT, "knight pushed to d4")
	check(s.piece_at(_sq("d3")) == null)


func test_stone_push_blocked() -> void:
	var s := _state("4k3/8/8/8/3p4/3n4/3R4/4K3 w - - 0 1")
	check(find_action(s, "stone_push:d2>d3") == null, "cannot push into an occupied square")


func test_swap_same_colour_only() -> void:
	var s := _state("4k3/8/8/8/8/8/8/R1B1K1NR w Q - 0 1")
	check(find_action(s, "swap:c1>g1") != null, "c1 and g1 are both dark squares")
	check(find_action(s, "swap:c1>h1") == null, "h1 is a light square")
	check_eq(s.castling_string(), "Q")
	play(s, ["swap:c1>a1"])
	check_eq(s.piece_at(_sq("c1")).kind, Chess.Kind.ROOK)
	check_eq(s.castling_string(), "-", "a teleported rook loses castling")


func test_fire_breath_lava_blocks() -> void:
	var s := _state("4k3/8/8/8/8/8/8/R2NK3 w - - 0 1")
	play(s, ["fire_breath:d1>c1"])
	check(s.is_lava(_sq("c1")))
	play(s, ["e8e7"])
	check(find_action(s, "a1b1") != null, "rook can reach b1")
	check(find_action(s, "a1c1") == null, "cannot land on lava")
	play(s, ["e1f1", "e7e8", "f1e1", "e8e7"])
	check(not s.is_lava(_sq("c1")), "lava cools after 2 rounds")


func test_lava_blocks_check() -> void:
	var s := _state("4k3/8/8/8/8/8/4N3/R3K3 b - - 0 1")
	s.hazards[_sq("e4")] = s.ply + 4
	s.board[_sq("e2")] = null
	s.board[_sq("e5")] = Piece.new(99, Chess.Kind.ROOK, Chess.WHITE)
	check(Rules.in_check(s, Chess.BLACK), "rook on e5 checks e8")
	s.hazards[_sq("e6")] = s.ply + 4
	check(not Rules.in_check(s, Chess.BLACK), "lava on e6 blocks the check")


func test_charge() -> void:
	var s := _state("4k3/8/8/8/8/4P3/8/4K3 w - - 0 1")
	play(s, ["charge:e3>e5"])
	check_eq(s.piece_at(_sq("e5")).kind, Chess.Kind.PAWN)
	check_eq(s.halfmove_clock, 0, "pawn advance resets the 50-move clock")


func test_charge_not_to_promotion_rank() -> void:
	var s := _state("4k3/8/4P3/8/8/8/8/4K3 w - - 0 1")
	s.board[_sq("e8")] = null
	s.board[_sq("a8")] = Piece.new(50, Chess.Kind.KING, Chess.BLACK)
	check(find_action(s, "charge:e6>e8") == null)


func test_ability_cannot_expose_own_king() -> void:
	# The white knight on e2 is pinned by the rook on e8. Breathing fire keeps the
	# knight in place, so it is legal.
	var s := _state("4r1k1/8/8/8/8/8/4N3/4K2B w - - 0 1")
	check(find_action(s, "fire_breath:e2>d2") != null, "the knight stays, so it is legal")
	s.board[_sq("h1")] = null
	s.board[_sq("g1")] = null
	s.board[_sq("c4")] = Piece.new(77, Chess.Kind.BISHOP, Chess.WHITE)
	# Swapping the pinned knight with a bishop keeps a blocker on e2, so it is legal.
	check(find_action(s, "swap:c4>e2") != null, "bishop keeps blocking the pin")


func test_push_enemy_rook() -> void:
	# The rook on b1 shoves the black rook on b2 back to b3.
	var s := _state("6k1/8/8/8/8/8/1r3PPP/1R4K1 w - - 0 1")
	check(find_action(s, "stone_push:b1>b2") != null, "push b2 -> b3 is legal")


func test_no_powers_while_in_check() -> void:
	# Fool's mate with powers on: lava on f2 would block the queen, but powers
	# are not allowed while in check, so it is still checkmate.
	var s := GameState.new_game(true)
	play(s, ["f2f3", "e7e5", "g2g4"])
	s.energy = [10, 10]
	play(s, ["d8h4"])
	check(Rules.legal_abilities(s).is_empty(), "no powers in check")
	check_eq(Rules.game_result(s)["reason"], "checkmate")
