extends TestCase
## World rules: movement, palace walls and gate, fights, recruiting, turns, fog.


func _sq(n: String) -> int:
	return Chess.parse_square(n)


func _empty() -> GameState:
	var s := GameState.empty()
	put(s, "a1", Chess.Kind.KING, Chess.WHITE).hp = 30
	put(s, "D30", Chess.Kind.KING, Chess.BLACK)
	return s


func test_new_game_setup() -> void:
	var s := GameState.new_game(true, 1)
	check_eq(s.all_pieces().size(), 10, "king, queen, miner and 2 soldiers per side")
	check_eq(s.structures.size(), 6, "2 gates and 4 towers")
	check_eq(s.palace_owner(s.find_king(Chess.WHITE)), Chess.WHITE, "the king sits in his palace")
	check_eq(s.palace_owner(s.find_king(Chess.BLACK)), Chess.BLACK)
	check_eq(int(s.gate_of(Chess.WHITE)["square"]), _sq("o7"))


func test_king_stays_in_palace() -> void:
	var s := GameState.new_game(true, 1)
	var k := s.find_king(Chess.WHITE)
	for to in MoveGen.reachable(s, k):
		check_eq(s.palace_owner(to), Chess.WHITE, "king step outside the palace: " + Chess.square_name(to))


func test_steps_and_forest() -> void:
	var s := _empty()
	put(s, "e5", Chess.Kind.PAWN, Chess.WHITE)  # 3 steps
	var r := MoveGen.reachable(s, _sq("e5"))
	check(r.has(_sq("e8")) and not r.has(_sq("e9")), "3 steps")
	s.terrain[_sq("e6")] = Chess.Terrain.FOREST
	s.terrain[_sq("d6")] = Chess.Terrain.FOREST
	s.terrain[_sq("f6")] = Chess.Terrain.FOREST
	r = MoveGen.reachable(s, _sq("e5"))
	check_eq(int(r.get(_sq("e6"), -1)), 2, "forest costs 2 steps")


func test_water_and_flying() -> void:
	var s := _empty()
	for f in Chess.W:
		s.terrain[Chess.sq(f, 6)] = Chess.Terrain.WATER
	put(s, "e6", Chess.Kind.PAWN, Chess.WHITE)
	check(not MoveGen.reachable(s, _sq("e6")).has(_sq("e8")), "soldiers cannot cross water")
	put(s, "h6", Chess.Kind.DRAGON, Chess.WHITE)
	check(MoveGen.reachable(s, _sq("h6")).has(_sq("h8")), "dragons fly over it")


func test_gate_blocks_enemies() -> void:
	var s := GameState.new_game(true, 1)
	s.board = []
	s.board.resize(Chess.N)
	var gate := _sq("o7")
	put(s, "o9", Chess.Kind.KNIGHT, Chess.BLACK)
	s.side_to_move = Chess.BLACK
	check(not MoveGen.reachable(s, _sq("o9")).has(gate), "the enemy gate is closed")
	put(s, "o8", Chess.Kind.GIANT, Chess.BLACK)
	check(MoveGen.attack_targets(s, _sq("o8")).has(gate), "but it can be attacked")
	var hp: int = s.gate_of(Chess.WHITE)["hp"]
	Rules.apply_action(s, GameAction.attack(_sq("o8"), gate), Rules.Outcome.AVERAGE)
	check(int(s.gate_of(Chess.WHITE)["hp"]) < hp - 6, "giants smash gates (double damage)")


func test_attack_and_counter() -> void:
	var s := _empty()
	var a := put(s, "e5", Chess.Kind.PAWN, Chess.WHITE)
	var d := put(s, "e6", Chess.Kind.PAWN, Chess.BLACK)
	var events := Rules.apply_action(s, GameAction.attack(_sq("e5"), _sq("e6")), Rules.Outcome.AVERAGE)
	# soldier 4 atk - 1 armour = 3; counter = 50% of 3 = 2 (rounded)
	check_eq(d.hp, 12 - 3)
	check_eq(a.hp, 12 - 2, "the defender hits back")
	check(events[0]["type"] == "attack")
	check(MoveGen.reachable(s, _sq("e5")).is_empty(), "after attacking it cannot move")


func test_archer_takes_no_counter_from_melee() -> void:
	var s := _empty()
	var a := put(s, "e5", Chess.Kind.ARCHER, Chess.WHITE)
	put(s, "e8", Chess.Kind.PAWN, Chess.BLACK)
	Rules.apply_action(s, GameAction.attack(_sq("e5"), _sq("e8")), Rules.Outcome.AVERAGE)
	check_eq(a.hp, a.max_hp, "a soldier 3 squares away cannot hit back")


func test_death_and_king_win() -> void:
	var s := _empty()
	s.piece_at(_sq("D30")).hp = 3
	put(s, "C29", Chess.Kind.DRAGON, Chess.WHITE)
	Rules.apply_action(s, GameAction.attack(_sq("C29"), _sq("D30")), Rules.Outcome.AVERAGE)
	check_eq(Rules.game_result(s)["result"], Rules.Result.WHITE_WINS, "killing the king wins the war")


func test_tower_breach() -> void:
	var s := GameState.new_game(true, 1)
	var tower := _sq("l7")
	check_eq(s.terrain_at(tower), Chess.Terrain.WALL)
	s.structure_at(tower)["hp"] = 1
	put(s, "l8", Chess.Kind.GIANT, Chess.BLACK)
	s.side_to_move = Chess.BLACK
	Rules.apply_action(s, GameAction.attack(_sq("l8"), tower), Rules.Outcome.AVERAGE)
	check(s.structure_at(tower).is_empty(), "the tower fell")
	check_eq(s.terrain_at(tower), Chess.Terrain.PLAIN, "and left a breach in the wall")


func test_recruit_at_gate() -> void:
	var s := GameState.new_game(true, 1)
	s.energy = [10, 10]
	var acts := Rules.recruit_actions(s)
	check(not acts.is_empty(), "can recruit")
	var a: GameAction = acts.filter(func(x): return x.kind == Chess.Kind.ARCHER)[0]
	Rules.apply_action(s, a)
	check_eq(int(s.energy[0]), 7, "an archer costs 3")
	check_eq(s.piece_at(a.to).kind, Chess.Kind.ARCHER)
	check(Chess.distance(a.to, _sq("o7")) <= 1, "it appears at the gate")
	check(MoveGen.reachable(s, a.to).is_empty(), "new units wait until next turn")


func test_end_turn_income_and_reset() -> void:
	var s := GameState.new_game(true, 1)
	var miner := s.find_piece(s.piece_at(_sq("n5")).id)
	Rules.apply_action(s, GameAction.move(miner, _sq("n6")))
	check(s.piece_at(_sq("n6")).moved)
	var before := int(s.energy[1])
	Rules.apply_action(s, GameAction.end_turn())
	check_eq(s.side_to_move, Chess.BLACK)
	check_eq(int(s.energy[1]), before + 1, "the Void miner makes 1 energy")
	Rules.apply_action(s, GameAction.end_turn())
	check(not s.piece_at(_sq("n6")).moved, "units are ready again on their next turn")


func test_tower_shoots() -> void:
	var s := GameState.new_game(true, 1)
	var v := put(s, "l9", Chess.Kind.PAWN, Chess.BLACK)
	s.side_to_move = Chess.BLACK
	var events := Rules.apply_action(s, GameAction.end_turn())
	check(events.any(func(e): return e["type"] == "tower_shot"), "a palace tower fires at the start of its turn")
	check(v.hp < v.max_hp)


func test_fog_of_war() -> void:
	var s := GameState.new_game(true, 1)
	var vis := s.visible_squares(Chess.WHITE)
	check_eq(vis[s.find_king(Chess.WHITE)], 1)
	check_eq(vis[s.find_king(Chess.BLACK)], 0, "the enemy palace is hidden at the start")
	check_eq(s.explored[0][_sq("o20")], 0)


func test_dice_are_repeatable() -> void:
	var a := GameState.new_game(true, 99)
	var b := GameState.new_game(true, 99)
	for i in 5:
		check_eq(a.roll_d100(), b.roll_d100())
