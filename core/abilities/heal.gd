extends Ability
## Healer - "Healing Light": a wounded friendly unit next to the healer (or the
## healer itself) gets back health.

var amount: int = 6


func _init() -> void:
	id = "heal"
	piece_kind = Chess.Kind.HEALER


func load_balance() -> void:
	super.load_balance()
	amount = int(Balance.ability(id).get("amount", amount))


func targets(state: GameState, from: int) -> Array:
	var me := state.piece_at(from)
	var out := []
	for s in [from] + Ability.neighbors(from, Chess.KING_OFFSETS):
		var t := state.piece_at(s)
		if t != null and t.color == me.color and t.hp < t.max_hp:
			out.append(s)
	return out


func apply(state: GameState, _from: int, target: int, events: Array) -> void:
	var t := state.piece_at(target)
	var before := t.hp
	t.hp = mini(t.max_hp, t.hp + amount)
	events.append({ "type": "heal", "piece_id": t.id, "square": target, "amount": t.hp - before })
