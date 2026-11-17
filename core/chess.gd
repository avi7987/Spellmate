class_name Chess
extends RefCounted
## Shared constants and small helpers for the rules engine.
## Squares are ints 0..63: square = rank * 8 + file. Rank 0 is White's back rank.

enum Kind { NONE = 0, PAWN = 1, KNIGHT = 2, BISHOP = 3, ROOK = 4, QUEEN = 5, KING = 6 }

const WHITE := 0
const BLACK := 1

const FILES := "abcdefgh"
const KIND_CHARS := { Kind.PAWN: "p", Kind.KNIGHT: "n", Kind.BISHOP: "b", Kind.ROOK: "r", Kind.QUEEN: "q", Kind.KING: "k" }

const KNIGHT_OFFSETS := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const KING_OFFSETS := [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]]
const ROOK_DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1]]
const BISHOP_DIRS := [[1, 1], [1, -1], [-1, 1], [-1, -1]]


static func sq(file: int, rank: int) -> int:
	return rank * 8 + file


static func file_of(s: int) -> int:
	return s & 7


static func rank_of(s: int) -> int:
	return s >> 3


static func on_board(file: int, rank: int) -> bool:
	return file >= 0 and file < 8 and rank >= 0 and rank < 8


static func other(color: int) -> int:
	return 1 - color


static func is_light_square(s: int) -> bool:
	return (file_of(s) + rank_of(s)) % 2 == 1


## Direction a pawn of this color walks (+1 rank for White, -1 for Black).
static func forward(color: int) -> int:
	return 1 if color == WHITE else -1


static func promotion_rank(color: int) -> int:
	return 7 if color == WHITE else 0


static func square_name(s: int) -> String:
	if s < 0 or s > 63:
		return "-"
	return FILES[file_of(s)] + str(rank_of(s) + 1)


static func parse_square(text: String) -> int:
	if text.length() != 2:
		return -1
	var f := FILES.find(text[0])
	var r := int(text[1]) - 1
	if f < 0 or r < 0 or r > 7:
		return -1
	return sq(f, r)


static func kind_from_char(c: String) -> int:
	for k in KIND_CHARS:
		if KIND_CHARS[k] == c.to_lower():
			return k
	return Kind.NONE
