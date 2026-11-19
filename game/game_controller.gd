class_name GameController
extends Node
## Runs a match: owns the GameState, checks that actions are legal, keeps
## the undo history, asks the AI for moves, and tells everyone what happened
## through signals. The board view and HUD only listen - they never change
## the state themselves.

signal game_started(state: GameState)
signal action_applied(action: GameAction, events: Array, state: GameState)
signal state_reset(state: GameState)   ## after undo / new game: redraw everything
signal game_over(result: Dictionary)
signal ai_thinking(active: bool)

enum PlayerType { HUMAN, AI }

var state: GameState
var players: Array = [PlayerType.HUMAN, PlayerType.HUMAN]
var ai_level: int = 1
var result: Dictionary = { "result": Rules.Result.ONGOING, "reason": "" }
## Set by the board while an animation/combat plays, so the AI waits for it.
var busy: bool = false

var _undo_stack: Array = []
var _ai := AiPlayer.new()


func new_game(vs_ai: bool, with_abilities: bool, level: int = 1, human_color: int = Chess.WHITE) -> void:
	state = GameState.new_game(with_abilities)
	players = [PlayerType.HUMAN, PlayerType.HUMAN]
	if vs_ai:
		players[Chess.other(human_color)] = PlayerType.AI
	ai_level = level
	_undo_stack.clear()
	result = { "result": Rules.Result.ONGOING, "reason": "" }
	game_started.emit(state)
	_maybe_ai_turn()


func is_vs_ai() -> bool:
	return players.has(PlayerType.AI)


func is_over() -> bool:
	return result["result"] != Rules.Result.ONGOING


func is_human_turn() -> bool:
	return not is_over() and players[state.side_to_move] == PlayerType.HUMAN


## Called by the UI (human) or the AI. Returns false if the action is illegal.
func submit_action(action: GameAction) -> bool:
	if is_over() or not Rules.is_legal(state, action):
		return false
	_undo_stack.append(state.clone())
	if _undo_stack.size() > 150:
		_undo_stack.pop_front()
	var events := Rules.apply_action(state, action)
	result = Rules.game_result(state)
	action_applied.emit(action, events, state)
	if is_over():
		game_over.emit(result)
	return true


func can_undo() -> bool:
	return not _undo_stack.is_empty()


## Undo the last action. Against the AI, undo back to the human's turn.
func undo() -> void:
	if _undo_stack.is_empty():
		return
	state = _undo_stack.pop_back()
	while players[state.side_to_move] == PlayerType.AI and not _undo_stack.is_empty():
		state = _undo_stack.pop_back()
	result = { "result": Rules.Result.ONGOING, "reason": "" }
	state_reset.emit(state)


## The board calls this when its animations are finished.
func on_presentation_done() -> void:
	busy = false
	_maybe_ai_turn()


func _maybe_ai_turn() -> void:
	if is_over() or busy or players[state.side_to_move] != PlayerType.AI:
		return
	ai_thinking.emit(true)
	# Wait a moment so the screen can update before the (blocking) search.
	await get_tree().create_timer(0.12).timeout
	if is_over() or players[state.side_to_move] != PlayerType.AI:
		ai_thinking.emit(false)
		return
	var action := _ai.choose_action(state, ai_level)
	ai_thinking.emit(false)
	if action != null:
		submit_action(action)
