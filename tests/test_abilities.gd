extends TestCase
## The super powers.


func _state(energy: int = 10) -> GameState:
	var s := GameState.empty()
	s.energy = [energy, energy]
	put(s, "a1", Chess.Kind.KING, Chess.WHITE)
	put(s, "D30", Chess.Kind.KING, Chess.BLACK)
	return s


func _sq(name: String) -> int:
	return Chess.parse_square(name)


func test_frost_storm() -> void:
	var s := _state()
	put(s, "e5", Chess.Kind.QUEEN, Chess.WHITE)
	var t := put(s, "e8", Chess.Kind.PAWN, Chess.BLACK)
	var near := put(s, "f9", Chess.Kind.ARCHER, Chess.BLACK)
	play(s, ["frost:e5>e8"])
	check(s.is_frozen(t) and s.is_frozen(near), "target and neighbours freeze")
	check_eq(t.hp, t.max_hp - 4, "and take frost damage")
	check_eq(int(s.energy[0]), 6, "costs 4")


func test_fire_breath() -> void:
	var s := _state()
	put(s, "e5", Chess.Kind.DRAGON, Chess.WHITE)
	var t := put(s, "e7", Chess.Kind.PAWN, Chess.BLACK)
	play(s, ["fire_breath:e5>e6"])
	check(s.is_lava(_sq("e6")) and s.is_lava(_sq("e7")), "a plus of fire")
	check_eq(t.hp, t.max_hp - 5)


func test_heal() -> void:
	var s := _state()
	put(s, "e5", Chess.Kind.HEALER, Chess.WHITE)
	var hurt := put(s, "e6", Chess.Kind.PAWN, Chess.WHITE)
	hurt.hp = 3
	play(s, ["heal:e5>e6"])
	check_eq(hurt.hp, 9)


func test_brace() -> void:
	var s := _state()
	var a := put(s, "e5", Chess.Kind.PAWN, Chess.WHITE)
	var b := put(s, "f5", Chess.Kind.PAWN, Chess.WHITE)
	play(s, ["brace:e5>e5"])
	check(s.is_braced(a) and s.is_braced(b), "the shield wall")


func test_toil() -> void:
	var s := _state(4)
	put(s, "c2", Chess.Kind.MINER, Chess.WHITE)
	play(s, ["toil:c2>c2"])
	check_eq(int(s.energy[0]), 7)


func test_royal_decree() -> void:
	var s := _state()
	var friend := put(s, "b2", Chess.Kind.PAWN, Chess.WHITE)
	play(s, ["royal_decree:a1>a1"])
	check(s.is_shielded(friend))


func test_power_uses_the_action() -> void:
	var s := _state()
	put(s, "e5", Chess.Kind.QUEEN, Chess.WHITE)
	put(s, "e8", Chess.Kind.PAWN, Chess.BLACK)
	play(s, ["frost:e5>e8"])
	check(Rules.legal_actions_from(s, _sq("e5")).is_empty(), "after a power the unit is done")
