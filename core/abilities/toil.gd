extends Ability
## Miner - "Double Shift": instead of moving, the miner works hard and adds
## extra energy right away (abilities.toil.gain in data/balance.json).

var gain: int = 2


func _init() -> void:
	id = "toil"
	piece_kind = Chess.Kind.MINER


func load_balance() -> void:
	super.load_balance()
	gain = int(Balance.ability(id).get("gain", gain))


func targets(_state: GameState, from: int) -> Array:
	return [from]


func apply(state: GameState, from: int, _target: int, events: Array) -> void:
	var p := state.piece_at(from)
	state.add_energy(p.color, gain)
	events.append({ "type": "toil", "piece_id": p.id, "square": from, "amount": gain })
