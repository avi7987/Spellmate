extends TestCase
## Perft = counting every possible move sequence to a given depth and comparing
## with known correct numbers. If these pass, the chess rules are correct
## (castling, en passant, promotion, pins, checks...).


func _perft(fen: String, expected: Array) -> void:
	var s := GameState.from_fen(fen)
	for i in expected.size():
		check_eq(Rules.perft(s, i + 1), expected[i], "%s depth %d:" % [fen, i + 1])


func test_start_position() -> void:
	_perft(GameState.START_FEN, [20, 400, 8902])


func test_kiwipete() -> void:
	_perft("r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1", [48, 2039])


func test_position_3_endgame() -> void:
	_perft("8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1", [14, 191, 2812])


func test_position_4_promotions() -> void:
	_perft("r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1", [6, 264])


func test_position_5() -> void:
	_perft("rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8", [44, 1486])
