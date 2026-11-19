class_name Chess
extends RefCounted
## Shared constants and small helpers for the rules engine.
## The world is W x H squares. square = rank * W + file. Rank 0 is the
## Sun's (White's) edge, rank H-1 the Void's (Black's).
## (The class keeps the name "Chess" - the game was born from chess.)

const W := 30
const H := 30
const N := W * H

enum Kind {
	NONE = 0, PAWN = 1, KNIGHT = 2, BISHOP = 3, ROOK = 4, QUEEN = 5, KING = 6, MINER = 7,
	ARCHER = 8, SHIELD = 9, HEALER = 10, ICE_WITCH = 11, FIRE_MAGE = 12, ASSASSIN = 13,
	GIANT = 14, BALLISTA = 15, DRAGON = 16,
}
enum Terrain { PLAIN, FOREST, HILL, WATER, BRIDGE, MINE, CASTLE, WALL }

const WHITE := 0   ## the Sun kingdom
const BLACK := 1   ## the Void kingdom

const FILES := "abcdefghijklmnopqrstuvwxyzABCD"
## Kind -> id used in data files. (pawn = soldier, knight = rider, bishop/rook are unused now.)
const KIND_NAMES := {
	Kind.PAWN: "pawn", Kind.KNIGHT: "knight", Kind.BISHOP: "bishop", Kind.ROOK: "rook",
	Kind.QUEEN: "queen", Kind.KING: "king", Kind.MINER: "miner", Kind.ARCHER: "archer",
	Kind.SHIELD: "shield", Kind.HEALER: "healer", Kind.ICE_WITCH: "ice_witch",
	Kind.FIRE_MAGE: "fire_mage", Kind.ASSASSIN: "assassin", Kind.GIANT: "giant",
	Kind.BALLISTA: "ballista", Kind.DRAGON: "dragon",
}
## Map characters. Palace walls, gates and towers: "#" wall, "G" gate, "T" tower
## (gates and towers are also structures with health - see GameState.structures).
const TERRAIN_CHARS := {
	".": Terrain.PLAIN, "f": Terrain.FOREST, "h": Terrain.HILL, "~": Terrain.WATER,
	"=": Terrain.BRIDGE, "m": Terrain.MINE, "p": Terrain.CASTLE, "#": Terrain.WALL,
	"G": Terrain.CASTLE, "T": Terrain.WALL,
}

const KNIGHT_OFFSETS := [[1, 2], [2, 1], [2, -1], [1, -2], [-1, -2], [-2, -1], [-2, 1], [-1, 2]]
const KING_OFFSETS := [[1, 0], [1, 1], [0, 1], [-1, 1], [-1, 0], [-1, -1], [0, -1], [1, -1]]
const ROOK_DIRS := [[1, 0], [-1, 0], [0, 1], [0, -1]]
const BISHOP_DIRS := [[1, 1], [1, -1], [-1, 1], [-1, -1]]


static func sq(file: int, rank: int) -> int:
	return rank * W + file


static func file_of(s: int) -> int:
	return s % W


static func rank_of(s: int) -> int:
	@warning_ignore("integer_division")
	return s / W


static func on_board(file: int, rank: int) -> bool:
	return file >= 0 and file < W and rank >= 0 and rank < H


static func other(color: int) -> int:
	return 1 - color


static func is_light_square(s: int) -> bool:
	return (file_of(s) + rank_of(s)) % 2 == 1


## The square seen from the other side (the map and armies are point-symmetric).
static func mirror(s: int) -> int:
	return sq(W - 1 - file_of(s), H - 1 - rank_of(s))


static func square_name(s: int) -> String:
	if s < 0 or s >= N:
		return "-"
	return FILES[file_of(s)] + str(rank_of(s) + 1)


static func parse_square(text: String) -> int:
	if text.length() < 2:
		return -1
	var f := FILES.find(text[0])
	var r := int(text.substr(1)) - 1
	if f < 0 or r < 0 or r >= H:
		return -1
	return sq(f, r)


static func kind_from_name(name: String) -> int:
	for k in KIND_NAMES:
		if KIND_NAMES[k] == name:
			return k
	return Kind.NONE


static func distance(a: int, b: int) -> int:
	return maxi(absi(file_of(a) - file_of(b)), absi(rank_of(a) - rank_of(b)))
