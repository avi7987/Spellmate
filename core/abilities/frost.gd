extends Ability
## Queen - "Frost Storm": an enemy unit (not the king) within the queen's
## range and every enemy next to it take frost damage and freeze for a turn.

var damage: int = 4


func _init() -> void:
	id = "frost"
	piece_kind = Chess.Kind.QUEEN
	duration = 2


func load_balance() -> void:
	super.load_balance()
	damage = int(Balance.ability(id).get("damage", damage))


func targets(state: GameState, from: int) -> Array:
	var q := state.piece_at(from)
	var out := []
	var reach := UnitData.attack_range(q.kind)
	for s in Chess.N:
		var t := state.piece_at(s)
		if t != null and t.color != q.color and t.kind != Chess.Kind.KING and Chess.distance(from, s) <= reach:
			out.append(s)
	return out


func apply(state: GameState, from: int, target: int, events: Array) -> void:
	var me := state.piece_at(from).color
	events.append({ "type": "frost_storm", "square": target })
	for s in [target] + Ability.neighbors(target, Chess.KING_OFFSETS):
		var t := state.piece_at(s)
		if t != null and t.color != me and t.kind != Chess.Kind.KING:
			state.freezes[t.id] = state.ply + duration
			t.hp -= damage
			events.append({ "type": "freeze", "piece_id": t.id, "square": s, "damage": damage })
	Rules._bury(state, events)
