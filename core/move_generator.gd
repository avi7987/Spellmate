class_name MoveGen
extends RefCounted
## Where can a unit walk, and whom can it hit?
##  - every unit has move points (data/units.json); forests cost 2 (assassins and
##    flyers pay 1), water and walls are closed (flyers cross them)
##  - you may walk through your own units but not stop on them; enemies block
##  - a standing enemy gate blocks the way: break it first
##  - slowed units have 2 fewer steps; frozen units cannot do anything


## Squares the unit on `from` can walk to this turn: square -> steps used.
static func reachable(state: GameState, from: int) -> Dictionary:
	var p := state.piece_at(from)
	var out := {}
	if p == null or p.moved or p.acted or state.is_frozen(p):
		return out
	var budget := UnitData.move_points(p.kind)
	if state.is_slowed(p):
		budget = maxi(1, budget - 2)
	var light := p.is_flying() or UnitData.trait_id(p.kind) == "shadow"
	var best := { from: 0 }
	var frontier := [from]
	while not frontier.is_empty():
		var cur: int = frontier.pop_front()
		var used: int = best[cur]
		for o in Chess.KING_OFFSETS:
			var f: int = Chess.file_of(cur) + o[0]
			var r: int = Chess.rank_of(cur) + o[1]
			if not Chess.on_board(f, r):
				continue
			var nxt := Chess.sq(f, r)
			if not state.can_enter(p, nxt):
				continue
			var occ := state.piece_at(nxt)
			if occ != null and occ.color != p.color:
				continue
			var step := 1
			if state.terrain[nxt] == Chess.Terrain.FOREST and not light:
				step = 2
			var total := used + step
			if total > budget:
				continue
			if not best.has(nxt) or int(best[nxt]) > total:
				best[nxt] = total
				frontier.append(nxt)
	for s in best:
		if s != from and state.piece_at(s) == null:
			out[s] = best[s]
	return out


## The shortest path from `from` to `to` (list of squares, ends at `to`), for animation.
static func path(state: GameState, from: int, to: int) -> Array:
	var p := state.piece_at(from)
	if p == null:
		return [to]
	var prev := { from: -1 }
	var frontier := [from]
	while not frontier.is_empty():
		var cur: int = frontier.pop_front()
		if cur == to:
			break
		for o in Chess.KING_OFFSETS:
			var f: int = Chess.file_of(cur) + o[0]
			var r: int = Chess.rank_of(cur) + o[1]
			if not Chess.on_board(f, r):
				continue
			var nxt := Chess.sq(f, r)
			if prev.has(nxt) or not state.can_enter(p, nxt):
				continue
			var occ := state.piece_at(nxt)
			if occ != null and occ.color != p.color:
				continue
			prev[nxt] = cur
			frontier.append(nxt)
	if not prev.has(to):
		return [to]
	var out := []
	var c := to
	while c != from and c != -1:
		out.push_front(c)
		c = prev[c]
	return out


## Squares with an enemy (unit, gate or tower) the unit could hit if it stood on `at`.
static func targets_from(state: GameState, unit_square: int, at: int) -> Array:
	var p := state.piece_at(unit_square)
	var out := []
	if p == null:
		return out
	var reach := UnitData.attack_range(p.kind)
	var min_reach := 2 if UnitData.trait_id(p.kind) == "artillery" else 1
	var cf := Chess.file_of(at)
	var cr := Chess.rank_of(at)
	for dr in range(-reach, reach + 1):
		for df in range(-reach, reach + 1):
			var d := maxi(absi(df), absi(dr))
			if d < min_reach or d > reach:
				continue
			if not Chess.on_board(cf + df, cr + dr):
				continue
			var s := Chess.sq(cf + df, cr + dr)
			var t := state.piece_at(s)
			if t != null and t.color != p.color and not state.is_shielded(t):
				out.append(s)
				continue
			var st := state.structure_at(s)
			if not st.is_empty() and int(st["color"]) != p.color:
				out.append(s)
	return out


## Whom can the unit on `from` attack right now (from where it stands)?
static func attack_targets(state: GameState, from: int) -> Array:
	var p := state.piece_at(from)
	if p == null or p.acted or state.is_frozen(p):
		return []
	if UnitData.trait_id(p.kind) == "artillery" and p.moved:
		return []   # a ballista cannot shoot in the turn it moved
	return targets_from(state, from, from)


## Enemy units that could attack `s` next turn (walk + hit). Used by the AI.
static func threats_to(state: GameState, s: int, color: int) -> Array:
	var out := []
	for from in Chess.N:
		var p := state.piece_at(from)
		if p == null or p.color != color or state.is_frozen(p):
			continue
		var reach := UnitData.move_points(p.kind) + UnitData.attack_range(p.kind) + 1
		if Chess.distance(from, s) <= reach:
			out.append(from)
	return out
