class_name GameState
extends RefCounted
## The complete state of a battle. Pure data - no graphics.
## Everything the rules need lives here (including the dice), so a state can
## be cloned for the AI, saved, or sent over a network.

## Units on the battlefield: Chess.N entries, each a Piece or null.
var board: Array = []
## Terrain of every square (Chess.Terrain).
var terrain: PackedInt32Array
var side_to_move: int = Chess.WHITE
## Half-turns played since the start. Effect timers are measured in plies.
var ply: int = 0
var energy: Array = [0, 0]
var abilities_enabled: bool = true
## Burning squares: square -> ply at which the fire goes out.
var hazards: Dictionary = {}
## Shielded units: piece id -> ply at which the shield ends.
var shields: Dictionary = {}
## Frozen units: piece id -> ply at which the freeze ends.
var freezes: Dictionary = {}
## Braced units (extra defense): piece id -> ply at which it ends.
var braces: Dictionary = {}
var next_piece_id: int = 1
## The dice. A simple deterministic generator, so a saved game replays exactly.
var rng_state: int = 12345
## -1 = battle still going, 0/1 = that side won, 2 = draw.
var winner: int = -1


func _init() -> void:
	board.resize(Chess.N)
	terrain = PackedInt32Array()
	terrain.resize(Chess.N)


## A new battle on the standard map with both armies.
static func new_game(with_abilities: bool = true, rng_seed: int = -1) -> GameState:
	var s := GameState.new()
	s.terrain = UnitData.terrain_grid()
	var army := UnitData.starting_army()
	for sq in army:
		s.add_piece(army[sq], Chess.WHITE, sq)
	for sq in army:
		s.add_piece(army[sq], Chess.BLACK, Chess.mirror(sq))
	s.abilities_enabled = with_abilities
	s.energy = [Balance.energy_start(), Balance.energy_start()]
	s.rng_state = rng_seed if rng_seed >= 0 else int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	s.gain_turn_energy()
	return s


## An empty plain battlefield (for tests and puzzles).
static func empty() -> GameState:
	var s := GameState.new()
	s.energy = [Balance.energy_start(), Balance.energy_start()]
	return s


# ---------------------------------------------------------------- queries

func piece_at(s: int) -> Piece:
	return board[s] if s >= 0 and s < Chess.N else null


func terrain_at(s: int) -> int:
	return terrain[s]


func find_king(color: int) -> int:
	for s in Chess.N:
		var p: Piece = board[s]
		if p != null and p.kind == Chess.Kind.KING and p.color == color:
			return s
	return -1


func find_piece(id: int) -> int:
	for s in Chess.N:
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


func is_braced(p: Piece) -> bool:
	return p != null and braces.has(p.id) and int(braces[p.id]) > ply


## Can a unit stand on / walk into this square (ignoring other units)?
func is_walkable(s: int) -> bool:
	return terrain[s] != Chess.Terrain.WATER and not is_lava(s)


func all_pieces() -> Array:
	var out := []
	for s in Chess.N:
		if board[s] != null:
			out.append(board[s])
	return out


func count(color: int, kind: int) -> int:
	var n := 0
	for p in all_pieces():
		if p.color == color and p.kind == kind:
			n += 1
	return n


## Energy this side earns at the start of each of its turns (from its miners).
func income(color: int) -> int:
	var total := 0
	for s in Chess.N:
		var p: Piece = board[s]
		if p != null and p.color == color and p.kind == Chess.Kind.MINER:
			total += Balance.energy_per_miner()
			if terrain[s] == Chess.Terrain.MINE:
				total += Balance.energy_mine_bonus()
	return total


# ---------------------------------------------------------------- changes

func add_piece(kind: int, color: int, s: int) -> Piece:
	var p := Piece.new(next_piece_id, kind, color)
	next_piece_id += 1
	board[s] = p
	return p


func gain_turn_energy() -> void:
	if abilities_enabled:
		add_energy(side_to_move, income(side_to_move))


func add_energy(color: int, amount: int) -> void:
	energy[color] = clampi(int(energy[color]) + amount, 0, Balance.energy_max())


## Rolls the dice: a number from 0 to 99.
func roll_d100() -> int:
	rng_state = (rng_state * 1103515245 + 12345) & 0x7fffffff
	return (rng_state >> 8) % 100


## Removes effects whose timer has ended.
func purge_expired() -> void:
	for dict in [hazards, shields, freezes, braces]:
		for key in dict.keys():
			if int(dict[key]) <= ply:
				dict.erase(key)


func clone() -> GameState:
	var c := GameState.new()
	for s in Chess.N:
		var p: Piece = board[s]
		c.board[s] = p.copy() if p != null else null
	c.terrain = terrain
	c.side_to_move = side_to_move
	c.ply = ply
	c.energy = energy.duplicate()
	c.abilities_enabled = abilities_enabled
	c.hazards = hazards.duplicate()
	c.shields = shields.duplicate()
	c.freezes = freezes.duplicate()
	c.braces = braces.duplicate()
	c.next_piece_id = next_piece_id
	c.rng_state = rng_state
	c.winner = winner
	return c
