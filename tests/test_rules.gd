extends TestCase
## Battlefield rules: movement, terrain, battles, energy and winning.


func _sq(n: String) -> int:
	return Chess.parse_square(n)


func _targets(state: GameState, from: String) -> Array:
	var out := []
	for t in MoveGen.reachable(state, _sq(from)):
		out.append(Chess.square_name(t))
	out.sort()
	return out


func test_new_game_setup() -> void:
	var s := GameState.new_game(true, 1)
	check_eq(s.all_pieces().size(), 28, "14 units per side")
	check_eq(Chess.square_name(s.find_king(Chess.WHITE)), "g1")
	check_eq(Chess.square_name(s.find_king(Chess.BLACK)), "f12", "the Void army is mirrored")
	check_eq(s.terrain_at(_sq("a6")), Chess.Terrain.WATER)
	check_eq(s.terrain_at(_sq("b6")), Chess.Terrain.BRIDGE)
	check_eq(s.terrain_at(_sq("d3")), Chess.Terrain.MINE)


func test_rook_has_limited_range() -> void:
	var s := GameState.empty()
	put(s, "a1", Chess.Kind.ROOK, Chess.WHITE)
	var t := _targets(s, "a1")
	check(t.has("a6") and not t.has("a7"), "rook range 5")
	check(t.has("f1") and not t.has("g1"))


func test_water_blocks_and_bridge_does_not() -> void:
	var s := GameState.new_game(true, 1)
	s.board = []
	s.board.resize(Chess.N)
	put(s, "a4", Chess.Kind.ROOK, Chess.WHITE)
	check(not _targets(s, "a4").has("a6"), "a6 is water")
	put(s, "b4", Chess.Kind.ROOK, Chess.WHITE)
	check(_targets(s, "b4").has("b7"), "b5/b6 are a bridge")


func test_forest_stops_sliding() -> void:
	var s := GameState.empty()
	s.terrain[_sq("c1")] = Chess.Terrain.FOREST
	put(s, "a1", Chess.Kind.ROOK, Chess.WHITE)
	var t := _targets(s, "a1")
	check(t.has("c1") and not t.has("d1"), "a rook stops when it enters a forest")


func test_knight_jumps_over_but_not_into_water() -> void:
	var s := GameState.empty()
	s.terrain[_sq("c3")] = Chess.Terrain.WATER
	put(s, "b1", Chess.Kind.KNIGHT, Chess.WHITE)
	put(s, "b2", Chess.Kind.PAWN, Chess.WHITE)
	var t := _targets(s, "b1")
	check(t.has("a3") and t.has("d2"), "jumps over units")
	check(not t.has("c3"), "cannot land in water")


func test_odds_add_up() -> void:
	var s := GameState.empty()
	put(s, "e4", Chess.Kind.KNIGHT, Chess.WHITE)
	put(s, "f6", Chess.Kind.ROOK, Chess.BLACK)
	# base 60 + knight charge 20 - rook stone skin 20 = 60
	check_eq(Combat.chance(s, _sq("e4"), _sq("f6")), 60)
	s.terrain[_sq("f6")] = Chess.Terrain.FOREST
	check_eq(Combat.chance(s, _sq("e4"), _sq("f6")), 45, "forest gives the defender 15")
	s.terrain[_sq("e4")] = Chess.Terrain.HILL
	check_eq(Combat.chance(s, _sq("e4"), _sq("f6")), 55, "hill gives the attacker 10")


func test_phalanx() -> void:
	var s := GameState.empty()
	put(s, "e4", Chess.Kind.QUEEN, Chess.WHITE)
	put(s, "e6", Chess.Kind.PAWN, Chess.BLACK)
	put(s, "d6", Chess.Kind.PAWN, Chess.BLACK)
	put(s, "f6", Chess.Kind.PAWN, Chess.BLACK)
	# 60 + queen 15 - two neighbouring soldiers 20 = 55
	check_eq(Combat.chance(s, _sq("e4"), _sq("e6")), 55)


func test_attacker_wins() -> void:
	var s := GameState.empty()
	var a := put(s, "e4", Chess.Kind.ROOK, Chess.WHITE)
	put(s, "e6", Chess.Kind.PAWN, Chess.BLACK)
	var events := Rules.apply_action(s, GameAction.move(_sq("e4"), _sq("e6")), Rules.Outcome.ATTACKER_WINS)
	check(s.piece_at(_sq("e6")) == a, "attacker takes the square")
	check(events.any(func(e): return e["type"] == "battle" and e["won"]))


func test_attacker_loses_and_dies() -> void:
	var s := GameState.empty()
	put(s, "e4", Chess.Kind.ROOK, Chess.WHITE)
	var d := put(s, "e6", Chess.Kind.PAWN, Chess.BLACK)
	Rules.apply_action(s, GameAction.move(_sq("e4"), _sq("e6")), Rules.Outcome.DEFENDER_WINS)
	check(s.piece_at(_sq("e4")) == null, "the attacker died")
	check(s.piece_at(_sq("e6")) == d, "the defender holds")


func test_bishop_phases_back() -> void:
	var s := GameState.empty()
	var b := put(s, "c1", Chess.Kind.BISHOP, Chess.WHITE)
	put(s, "e3", Chess.Kind.PAWN, Chess.BLACK)
	Rules.apply_action(s, GameAction.move(_sq("c1"), _sq("e3")), Rules.Outcome.DEFENDER_WINS)
	check(s.piece_at(_sq("c1")) == b, "a bishop that loses slips back home")


func test_killing_the_king_wins() -> void:
	var s := GameState.empty()
	put(s, "a1", Chess.Kind.KING, Chess.WHITE)
	put(s, "e4", Chess.Kind.QUEEN, Chess.WHITE)
	put(s, "e6", Chess.Kind.KING, Chess.BLACK)
	Rules.apply_action(s, GameAction.move(_sq("e4"), _sq("e6")), Rules.Outcome.ATTACKER_WINS)
	check_eq(Rules.game_result(s)["result"], Rules.Result.WHITE_WINS)
	check(Rules.legal_actions(s).is_empty(), "nothing to do after the war")


func test_dice_are_repeatable() -> void:
	var a := GameState.new_game(true, 99)
	var b := GameState.new_game(true, 99)
	for i in 5:
		check_eq(a.roll_d100(), b.roll_d100())


func test_miners_make_energy() -> void:
	var s := GameState.empty()
	put(s, "a1", Chess.Kind.KING, Chess.WHITE)
	put(s, "a12", Chess.Kind.KING, Chess.BLACK)
	put(s, "c2", Chess.Kind.MINER, Chess.WHITE)
	var on_mine := put(s, "d3", Chess.Kind.MINER, Chess.WHITE)
	s.terrain[_sq("d3")] = Chess.Terrain.MINE
	check_eq(s.income(Chess.WHITE), 3, "1 + (1 + 1 on the mine)")
	check_eq(s.income(Chess.BLACK), 0, "no miners, no energy")
	s.energy = [0, 0]
	play(s, ["a1b1", "a12b12"])
	check_eq(int(s.energy[Chess.WHITE]), 3, "income arrives at the start of the turn")
	s.board[_sq("d3")] = null
	check_eq(s.income(Chess.WHITE), 1, "a dead miner stops working")


func test_pass_when_stuck() -> void:
	var s := GameState.empty()
	var k := put(s, "a1", Chess.Kind.KING, Chess.WHITE)
	s.freezes[k.id] = s.ply + 2
	var acts := Rules.legal_actions(s)
	check_eq(acts.size(), 1)
	check_eq(acts[0].type, GameAction.Type.PASS)
