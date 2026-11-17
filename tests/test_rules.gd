extends TestCase
## Classic chess rules: game end conditions and FEN round trip.


func test_fen_round_trip() -> void:
	for fen in [GameState.START_FEN, "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"]:
		check_eq(GameState.from_fen(fen).to_fen(), fen, "round trip")


func test_fools_mate() -> void:
	var s := GameState.from_fen(GameState.START_FEN)
	s.abilities_enabled = false
	play(s, ["f2f3", "e7e5", "g2g4", "d8h4"])
	var r := Rules.game_result(s)
	check_eq(r["result"], Rules.Result.BLACK_WINS)
	check_eq(r["reason"], "checkmate")


func test_stalemate() -> void:
	var s := GameState.from_fen("7k/5Q2/6K1/8/8/8/8/8 b - - 0 1")
	s.abilities_enabled = false
	check_eq(Rules.game_result(s)["reason"], "stalemate")


func test_insufficient_material() -> void:
	var s := GameState.from_fen("8/8/4k3/8/8/3NK3/8/8 w - - 0 1")
	check_eq(Rules.game_result(s)["reason"], "material")


func test_threefold_repetition() -> void:
	var s := GameState.new_game(false)
	play(s, ["g1f3", "g8f6", "f3g1", "f6g8", "g1f3", "g8f6", "f3g1", "f6g8"])
	check_eq(Rules.game_result(s)["reason"], "repetition")


func test_en_passant_and_events() -> void:
	var s := GameState.new_game(false)
	play(s, ["e2e4", "a7a6", "e4e5", "d7d5"])
	var a := find_action(s, "e5d6")
	check(a != null, "en passant should be legal")
	var events := Rules.apply_action(s, a)
	check(s.piece_at(Chess.parse_square("d5")) == null, "captured pawn removed")
	check(events.any(func(e): return e["type"] == "capture"), "capture event sent")


func test_promotion_keeps_piece_id() -> void:
	var s := GameState.from_fen("8/4P3/8/8/8/8/k7/4K3 w - - 0 1")
	var id := s.piece_at(Chess.parse_square("e7")).id
	play(s, ["e7e8n"])
	var p := s.piece_at(Chess.parse_square("e8"))
	check_eq(p.kind, Chess.Kind.KNIGHT)
	check_eq(p.id, id, "promoted piece id")
