class_name GameState
extends RefCounted
## The complete state of a game. Pure data - no graphics.
## Everything the rules need lives here, so a state can be cloned for the AI,
## saved, or sent over a network.

const START_FEN := "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1"

## 64 entries, each a Piece or null.
var board: Array = []
var side_to_move: int = Chess.WHITE
var ep_square: int = -1
var halfmove_clock: int = 0
var fullmove_number: int = 1
## Half-turns played since the start. Effect timers are measured in plies.
var ply: int = 0
var energy: Array = [0, 0]
var abilities_enabled: bool = true
## Lava squares: square -> ply at which the lava disappears.
var hazards: Dictionary = {}
## Shielded pieces: piece id -> ply at which the shield ends.
var shields: Dictionary = {}
## Frozen pieces: piece id -> ply at which the freeze ends.
var freezes: Dictionary = {}
var next_piece_id: int = 1
## Position keys of every position so far (for threefold repetition).
## Only filled when track_history is true (the AI's scratch copies skip it).
var history_keys: Array = []
var track_history: bool = true


func _init() -> void:
	board.resize(64)


static func new_game(with_abilities: bool = true) -> GameState:
	var s := from_fen(START_FEN)
	s.abilities_enabled = with_abilities
	s.energy = [Balance.energy_start(), Balance.energy_start()]
	if with_abilities:
		s.gain_turn_energy()
	s.history_keys = [s.position_key()]
	return s


# ---------------------------------------------------------------- queries

func piece_at(s: int) -> Piece:
	return board[s]


func find_king(color: int) -> int:
	for s in 64:
		var p: Piece = board[s]
		if p != null and p.kind == Chess.Kind.KING and p.color == color:
			return s
	return -1


func find_piece(id: int) -> int:
	for s in 64:
		var p: Piece = board[s]
		if p != null and p.id == id:
			return s
	return -1


func is_lava(s: int) -> bool:
	return hazards.has(s) and int(hazards[s]) > ply


func is_shielded(p: Piece) -> bool:
	return p != null and shields.has(p.id) and int(shields[p.id]) > ply


func is_frozen(p: Piece) -> bool:
	return p != null and freezes.has(p.id) and int(freezes[p.id]) > ply


func all_pieces() -> Array:
	var out := []
	for s in 64:
		if board[s] != null:
			out.append(board[s])
	return out


# ---------------------------------------------------------------- changes

func add_piece(kind: int, color: int, s: int) -> Piece:
	var p := Piece.new(next_piece_id, kind, color)
	next_piece_id += 1
	board[s] = p
	return p


func gain_turn_energy() -> void:
	add_energy(side_to_move, Balance.energy_per_turn())


func add_energy(color: int, amount: int) -> void:
	energy[color] = clampi(int(energy[color]) + amount, 0, Balance.energy_max())


## Removes effects whose timer has ended.
func purge_expired() -> void:
	for dict in [hazards, shields, freezes]:
		for key in dict.keys():
			if int(dict[key]) <= ply:
				dict.erase(key)


func clone(keep_history: bool = true) -> GameState:
	var c := GameState.new()
	for s in 64:
		var p: Piece = board[s]
		c.board[s] = p.copy() if p != null else null
	c.side_to_move = side_to_move
	c.ep_square = ep_square
	c.halfmove_clock = halfmove_clock
	c.fullmove_number = fullmove_number
	c.ply = ply
	c.energy = energy.duplicate()
	c.abilities_enabled = abilities_enabled
	c.hazards = hazards.duplicate()
	c.shields = shields.duplicate()
	c.freezes = freezes.duplicate()
	c.next_piece_id = next_piece_id
	c.track_history = keep_history and track_history
	if c.track_history:
		c.history_keys = history_keys.duplicate()
	return c


# ---------------------------------------------------------------- FEN

static func from_fen(fen: String) -> GameState:
	var s := GameState.new()
	var parts := fen.strip_edges().split(" ", false)
	var rows := parts[0].split("/")
	for i in 8:
		var rank := 7 - i
		var file := 0
		for ch in rows[i]:
			if ch.is_valid_int():
				file += int(ch)
			else:
				var color := Chess.WHITE if ch == ch.to_upper() else Chess.BLACK
				var p := s.add_piece(Chess.kind_from_char(ch), color, Chess.sq(file, rank))
				# Kings and rooks count as "moved" unless the castling field says otherwise.
				p.has_moved = p.kind == Chess.Kind.KING or p.kind == Chess.Kind.ROOK
				file += 1
	s.side_to_move = Chess.WHITE if parts.size() < 2 or parts[1] == "w" else Chess.BLACK
	var castling := parts[2] if parts.size() > 2 else "-"
	for c in castling:
		match c:
			"K": s._unmark_castle(Chess.WHITE, 7)
			"Q": s._unmark_castle(Chess.WHITE, 0)
			"k": s._unmark_castle(Chess.BLACK, 7)
			"q": s._unmark_castle(Chess.BLACK, 0)
	s.ep_square = Chess.parse_square(parts[3]) if parts.size() > 3 else -1
	s.halfmove_clock = int(parts[4]) if parts.size() > 4 else 0
	s.fullmove_number = int(parts[5]) if parts.size() > 5 else 1
	s.ply = (s.fullmove_number - 1) * 2 + s.side_to_move
	return s


func _unmark_castle(color: int, rook_file: int) -> void:
	var rank := 0 if color == Chess.WHITE else 7
	var king: Piece = board[Chess.sq(4, rank)]
	var rook: Piece = board[Chess.sq(rook_file, rank)]
	if king != null and king.kind == Chess.Kind.KING and king.color == color:
		king.has_moved = false
	if rook != null and rook.kind == Chess.Kind.ROOK and rook.color == color:
		rook.has_moved = false


func can_castle(color: int, rook_file: int) -> bool:
	var rank := 0 if color == Chess.WHITE else 7
	var king: Piece = board[Chess.sq(4, rank)]
	var rook: Piece = board[Chess.sq(rook_file, rank)]
	return king != null and king.kind == Chess.Kind.KING and king.color == color and not king.has_moved \
		and rook != null and rook.kind == Chess.Kind.ROOK and rook.color == color and not rook.has_moved


func castling_string() -> String:
	var c := ""
	if can_castle(Chess.WHITE, 7): c += "K"
	if can_castle(Chess.WHITE, 0): c += "Q"
	if can_castle(Chess.BLACK, 7): c += "k"
	if can_castle(Chess.BLACK, 0): c += "q"
	return c if c != "" else "-"


func board_fen() -> String:
	var rows := []
	for i in 8:
		var rank := 7 - i
		var row := ""
		var empty := 0
		for file in 8:
			var p: Piece = board[Chess.sq(file, rank)]
			if p == null:
				empty += 1
			else:
				if empty > 0:
					row += str(empty)
					empty = 0
				row += p.fen_char()
		if empty > 0:
			row += str(empty)
		rows.append(row)
	return "/".join(rows)


func to_fen() -> String:
	return "%s %s %s %s %d %d" % [board_fen(), "w" if side_to_move == Chess.WHITE else "b",
		castling_string(), Chess.square_name(ep_square), halfmove_clock, fullmove_number]


## Identifies "the same position" for repetition: board, side, castling,
## en passant, energy and active effects.
func position_key() -> String:
	var fx := []
	for s in hazards: fx.append("L%d:%d" % [s, int(hazards[s]) - ply])
	for id in shields: fx.append("S%d:%d" % [find_piece(id), int(shields[id]) - ply])
	for id in freezes: fx.append("F%d:%d" % [find_piece(id), int(freezes[id]) - ply])
	fx.sort()
	return "%s %d %s %d %d/%d %s" % [board_fen(), side_to_move, castling_string(), ep_square,
		energy[0], energy[1], ",".join(fx)]
