extends Ability
## Dragon - "Fire Breath": a square next to the dragon and the squares around it
## (a plus shape) burst into flames for 2 rounds. Enemies there take damage now,
## and anyone standing in fire at the start of their turn burns again.

var damage: int = 5


func _init() -> void:
	id = "fire_breath"
	piece_kind = Chess.Kind.DRAGON
	duration = 4


func load_balance() -> void:
	super.load_balance()
	damage = int(Balance.ability(id).get("damage", damage))


func targets(state: GameState, from: int) -> Array:
	var out := []
	for s in Ability.neighbors(from, Chess.KING_OFFSETS):
		var t := state.terrain[s]
		if t != Chess.Terrain.WATER and t != Chess.Terrain.WALL:
			out.append(s)
	return out


func apply(state: GameState, from: int, target: int, events: Array) -> void:
	var me := state.piece_at(from).color
	events.append({ "type": "firestorm", "square": target, "from": from })
	for s in [target] + Ability.neighbors(target, Chess.ROOK_DIRS):
		var t := state.terrain[s]
		if t == Chess.Terrain.WATER or t == Chess.Terrain.WALL:
			continue
		state.hazards[s] = state.ply + duration
		events.append({ "type": "lava", "square": s, "from": from })
		var u := state.piece_at(s)
		if u != null and u.color != me:
			u.hp -= damage
			events.append({ "type": "burn", "piece_id": u.id, "square": s, "damage": damage })
	Rules._bury(state, events)
