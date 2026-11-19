class_name GameState
extends RefCounted
## The complete state of a war. Pure data - no graphics.
## Everything the rules need lives here (including the dice and the fog), so a
## state can be cloned for the AI, saved, or sent over a network.

## Units: Chess.N entries, each a Piece or null.
var board: Array = []
## Terrain of every square (Chess.Terrain). Changes when a tower falls (it leaves a breach).
var terrain: PackedInt32Array
## Gates and towers: [{ id, kind: "gate"/"tower", color, square, hp, max_hp }]
var structures: Array = []
var side_to_move: int = Chess.WHITE
## Half-turns (one side's turn = one ply). Effect timers are measured in plies.
var ply: int = 0
var energy: Array = [0, 0]
var abilities_enabled: bool = true
## Burning squares: square -> ply at which the fire goes out.
var hazards: Dictionary = {}
## Effects on units: piece id -> ply at which the effect ends.
var shields: Dictionary = {}
var freezes: Dictionary = {}
var slows: Dictionary = {}
var braces: Dictionary = {}
var next_piece_id: int = 1
## The dice: a simple deterministic generator, so a saved game replays exactly.
var rng_state: int = 12345
## -1 = war still going, 0/1 = that side won, 2 = draw.
var winner: int = -1
## Squares each side has ever seen (1 = explored), for the fog of war.
var explored: Array = [PackedByteArray(), PackedByteArray()]


func _init() -> void:
	board.resize(Chess.N)
	terrain = PackedInt32Array()
	terrain.resize(Chess.N)
	for c in 2:
		var e := PackedByteArray()
		e.resize(Chess.N)
		explored[c] = e


## A new war on the standard map: both palaces and the starting armies.
static func new_game(with_abilities: bool = true, rng_seed: int = -1) -> GameState:
	var s := GameState.new()
	s.terrain = UnitData.terrain_grid()
	for st in UnitData.map_structures():
		var sq: int = st[0]
		var color := Chess.WHITE if Chess.rank_of(sq) < Chess.H / 2 else Chess.BLACK
		s.add_structure(st[1], color, sq)
	var army := UnitData.starting_army()
	for sq in army:
		s.add_piece(army[sq], Chess.WHITE, sq)
	for sq in army:
		s.add_piece(army[sq], Chess.BLACK, Chess.mirror(sq))
	s.abilities_enabled = with_abilities
	s.energy = [Balance.energy_start(), Balance.energy_start()]
	s.rng_state = rng_seed if rng_seed >= 0 else int(Time.get_unix_time_from_system() * 1000.0) % 2147483647
	s.update_explored()
	return s


## An empty plain world (for tests and puzzles).
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


func structure_at(s: int) -> Dictionary:
	for st in structures:
		if int(st["square"]) == s:
			return st
	return {}


func gate_of(color: int) -> Dictionary:
	for st in structures:
		if st["kind"] == "gate" and int(st["color"]) == color:
			return st
	return {}


## The palace a square belongs to (-1 = none). Palace floors are on each side's half.
func palace_owner(s: int) -> int:
	if terrain[s] != Chess.Terrain.CASTLE:
		return -1
	return Chess.WHITE if Chess.rank_of(s) < Chess.H / 2 else Chess.BLACK


func is_lava(s: int) -> bool:
	return hazards.has(s) and int(hazards[s]) > ply


func _active(dict: Dictionary, p: Piece) -> bool:
	return p != null and dict.has(p.id) and int(dict[p.id]) > ply


func is_shielded(p: Piece) -> bool:
	return _active(shields, p)


func is_frozen(p: Piece) -> bool:
	return _active(freezes, p)


func is_slowed(p: Piece) -> bool:
	return _active(slows, p)


func is_braced(p: Piece) -> bool:
	return _active(braces, p)


## Can unit `p` stand on square `s` (ignoring other units)?
func can_enter(p: Piece, s: int) -> bool:
	var t := terrain[s]
	if is_lava(s):
		return false
	if t == Chess.Terrain.WATER or t == Chess.Terrain.WALL:
		return p.is_flying()
	# A standing gate blocks the enemy.
	var st := structure_at(s)
	if not st.is_empty() and st["kind"] == "gate" and int(st["color"]) != p.color:
		return false
	# The king never leaves his palace.
	if p.kind == Chess.Kind.KING and palace_owner(s) != p.color:
		return false
	return true


func all_pieces() -> Array:
	var out := []
	for s in Chess.N:
		if board[s] != null:
			out.append(board[s])
	return out


func units_of(color: int) -> Array:
	var out := []
	for s in Chess.N:
		var p: Piece = board[s]
		if p != null and p.color == color:
			out.append(s)
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


# ---------------------------------------------------------------- fog of war

## Squares `color` can see right now (1 = visible).
func visible_squares(color: int) -> PackedByteArray:
	var vis := PackedByteArray()
	vis.resize(Chess.N)
	var eyes := []   # [square, radius]
	for s in Chess.N:
		var p: Piece = board[s]
		if p != null and p.color == color:
			var r := UnitData.vision(p.kind)
			if terrain[s] == Chess.Terrain.HILL:
				r += 2
			eyes.append([s, r])
	for st in structures:
		if int(st["color"]) == color:
			eyes.append([int(st["square"]), 5])
	for e in eyes:
		var c: int = e[0]
		var r: int = e[1]
		var cf := Chess.file_of(c)
		var cr := Chess.rank_of(c)
		for dr in range(-r, r + 1):
			for df in range(-r, r + 1):
				if df * df + dr * dr > r * r + 1:
					continue
				var f := cf + df
				var rr := cr + dr
				if Chess.on_board(f, rr):
					vis[Chess.sq(f, rr)] = 1
	# Your own palace is always in view.
	for s in Chess.N:
		if palace_owner(s) == color:
			vis[s] = 1
	return vis


func update_explored() -> void:
	for c in 2:
		var vis := visible_squares(c)
		var e: PackedByteArray = explored[c]
		for s in Chess.N:
			if vis[s] == 1:
				e[s] = 1
		explored[c] = e


# ---------------------------------------------------------------- changes

func add_piece(kind: int, color: int, s: int) -> Piece:
	var p := Piece.new(next_piece_id, kind, color)
	next_piece_id += 1
	board[s] = p
	return p


func add_structure(kind: String, color: int, s: int) -> Dictionary:
	var data := UnitData.structure(kind)
	var st := { "id": next_piece_id, "kind": kind, "color": color, "square": s,
		"hp": int(data.get("hp", 30)), "max_hp": int(data.get("hp", 30)) }
	next_piece_id += 1
	structures.append(st)
	return st


func add_energy(color: int, amount: int) -> void:
	energy[color] = clampi(int(energy[color]) + amount, 0, Balance.energy_max())


## Rolls the dice: a number from 0 to 99.
func roll_d100() -> int:
	rng_state = (rng_state * 1103515245 + 12345) & 0x7fffffff
	return (rng_state >> 8) % 100


## Removes effects whose timer has ended.
func purge_expired() -> void:
	for dict in [hazards, shields, freezes, slows, braces]:
		for key in dict.keys():
			if int(dict[key]) <= ply:
				dict.erase(key)


func clone() -> GameState:
	var c := GameState.new()
	for s in Chess.N:
		var p: Piece = board[s]
		c.board[s] = p.copy() if p != null else null
	c.terrain = terrain.duplicate()
	c.structures = []
	for st in structures:
		c.structures.append(st.duplicate())
	c.side_to_move = side_to_move
	c.ply = ply
	c.energy = energy.duplicate()
	c.abilities_enabled = abilities_enabled
	c.hazards = hazards.duplicate()
	c.shields = shields.duplicate()
	c.freezes = freezes.duplicate()
	c.slows = slows.duplicate()
	c.braces = braces.duplicate()
	c.next_piece_id = next_piece_id
	c.rng_state = rng_state
	c.winner = winner
	c.explored = [explored[0].duplicate(), explored[1].duplicate()]
	return c
