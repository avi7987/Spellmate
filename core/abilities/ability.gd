class_name Ability
extends RefCounted
## Base class for a piece's super power.
##
## To add a new ability:
##   1. Create a script in core/abilities/ that extends Ability.
##   2. Set id + piece_kind in _init(), implement targets() and apply().
##   3. Add its numbers to data/balance.json and register it in AbilityRegistry.
## Rules.gd takes care of energy, cooldown, frozen pieces and king safety.

var id: String = ""
var piece_kind: int = Chess.Kind.NONE
var cost: int = 0
## Cooldown in the owner's own turns.
var cooldown: int = 0
## How long the effect lasts, in plies (half-turns). 2 = until your next turn.
var duration: int = 0


func load_balance() -> void:
	var b := Balance.ability(id)
	cost = int(b.get("cost", cost))
	cooldown = int(b.get("cooldown", cooldown))
	duration = int(b.get("duration", duration))


## Is the piece on `from` allowed to use its power right now (ignoring targets)?
func can_activate(state: GameState, from: int) -> bool:
	var p := state.piece_at(from)
	return state.abilities_enabled and p != null and p.kind == piece_kind \
		and p.color == state.side_to_move and not state.is_frozen(p) and not p.acted \
		and int(state.energy[p.color]) >= cost and state.ply >= p.ability_ready_ply


## Turns until the ability is ready again (0 = ready).
func turns_until_ready(state: GameState, from: int) -> int:
	var p := state.piece_at(from)
	if p == null:
		return 0
	return maxi(0, ceili((p.ability_ready_ply - state.ply) / 2.0))


## Squares this ability may target from `from`. Override.
func targets(_state: GameState, _from: int) -> Array:
	return []


## Performs the effect. Append presentation events to `events`. Override.
func apply(_state: GameState, _from: int, _target: int, _events: Array) -> void:
	pass


# ------------------------------------------------------------ helpers

static func neighbors(s: int, offsets: Array) -> Array:
	var out := []
	for o in offsets:
		var f: int = Chess.file_of(s) + o[0]
		var r: int = Chess.rank_of(s) + o[1]
		if Chess.on_board(f, r):
			out.append(Chess.sq(f, r))
	return out
