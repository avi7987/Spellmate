extends Node3D
## Entry point: builds the scene (light, camera, board, HUD), connects the
## pieces together, and turns clicks into actions.
##
##   GameController  ── signals ──►  BoardView (3D)  +  Hud (2D)
##        ▲                                │
##        └──────── submit_action ◄── clicks on squares

enum Mode { IDLE, SELECTED, TARGETING, PROMOTION, BUSY }

var controller: GameController
var board: BoardView
var hud: Hud
var camera_rig: CameraRig
var combat: CombatDirector

## Rotate the board for whoever's turn it is in a two-player game.
var auto_flip := true

var _mode: int = Mode.IDLE
var _selected := -1
var _selected_actions: Array = []
var _pending_promotion: Array = []
var _last_move: Array = []


func _ready() -> void:
	_build_world()
	controller = GameController.new()
	add_child(controller)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	board = BoardView.new()
	board.camera_rig = camera_rig
	add_child(board)
	combat = CombatDirector.new()
	combat.board = board
	combat.camera_rig = camera_rig
	add_child(combat)
	board.combat = combat
	hud = Hud.new()
	add_child(hud)

	controller.game_started.connect(_on_game_started)
	controller.action_applied.connect(_on_action_applied)
	controller.state_reset.connect(_on_state_reset)
	controller.game_over.connect(func(r): hud.show_game_over(r))
	controller.ai_thinking.connect(func(on): hud.set_thinking(on))
	board.square_clicked.connect(_on_square_clicked)
	board.presentation_done.connect(_on_presentation_done)
	hud.new_game_requested.connect(func(vs_ai, powers, level): controller.new_game(vs_ai, powers, level))
	hud.undo_requested.connect(_on_undo)
	hud.power_pressed.connect(_on_power_pressed)
	hud.cancel_pressed.connect(_clear_selection)
	hud.promotion_chosen.connect(_on_promotion_chosen)

	# Show a board behind the menu right away.
	controller.new_game(true, true, 1)
	hud.show_menu(true, false)


func _build_world() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.35, 0.55, 0.95)
	sky_mat.sky_horizon_color = Color(0.85, 0.9, 1.0)
	sky_mat.ground_bottom_color = Color(0.3, 0.45, 0.25)
	sky_mat.ground_horizon_color = Color(0.7, 0.8, 0.6)
	sky_mat.energy_multiplier = 0.3   # the sky only feeds reflections on metal
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.9)
	env.ambient_light_energy = 0.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 0.95
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_hdr_threshold = 1.3
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-62, 25, 0)
	sun.light_energy = 0.75
	sun.light_color = Color(1.0, 0.96, 0.88)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)


# ------------------------------------------------------------ game events

func _on_game_started(state: GameState) -> void:
	_last_move = []
	_clear_selection()
	var yaw := _yaw_for(state)
	camera_rig.set_view_yaw(yaw, false)
	board.set_facing(yaw)
	board.sync(state)
	_refresh(state)


func _on_action_applied(action: GameAction, events: Array, state: GameState) -> void:
	_mode = Mode.BUSY
	controller.busy = true
	_last_move = [action.from, action.to] if action.is_move() else []
	board.clear_highlights()
	hud.hide_character()
	hud.update_state(state, controller)
	board.play_events(events, state)


func _on_presentation_done() -> void:
	var state := controller.state
	var yaw := _yaw_for(state)
	if yaw != camera_rig.view_yaw and not controller.is_over():
		camera_rig.set_view_yaw(yaw)
		board.set_facing(yaw)
	_mode = Mode.IDLE
	_refresh(state)
	controller.on_presentation_done()


func _on_state_reset(state: GameState) -> void:
	_last_move = []
	_clear_selection()
	board.sync(state)
	var yaw := _yaw_for(state)
	camera_rig.set_view_yaw(yaw)
	board.set_facing(yaw)
	_refresh(state)


func _on_undo() -> void:
	if _mode != Mode.BUSY:
		controller.undo()


## Human always at the bottom vs AI; in a local game the board turns each turn.
func _yaw_for(state: GameState) -> float:
	if controller.is_vs_ai():
		return 0.0 if controller.players[Chess.WHITE] == GameController.PlayerType.HUMAN else 180.0
	if not auto_flip:
		return 0.0
	return 0.0 if state.side_to_move == Chess.WHITE else 180.0


func _refresh(state: GameState) -> void:
	hud.update_state(state, controller)
	_draw_base_highlights(state)


func _draw_base_highlights(state: GameState) -> void:
	board.clear_highlights()
	for s in _last_move:
		board.highlight_square(s, Style.HL_LAST)
	if Rules.in_check(state, state.side_to_move):
		board.highlight_square(state.find_king(state.side_to_move), Style.HL_CHECK)


# ------------------------------------------------------------ clicking

func _on_square_clicked(s: int) -> void:
	if _mode == Mode.BUSY or _mode == Mode.PROMOTION or not controller.is_human_turn():
		return
	var state := controller.state
	if _mode == Mode.TARGETING:
		for a in _selected_actions:
			if a.type == GameAction.Type.ABILITY and a.to == s:
				controller.submit_action(a)
				return
		_clear_selection()
		return
	if _mode == Mode.SELECTED:
		var moves := _selected_actions.filter(func(a): return a.is_move() and a.to == s)
		if moves.size() == 1:
			controller.submit_action(moves[0])
			return
		if moves.size() > 1:  # promotion: let the player choose
			_pending_promotion = moves
			_mode = Mode.PROMOTION
			hud.show_promotion()
			return
	var p := state.piece_at(s)
	if p != null and p.color == state.side_to_move:
		_select(s)
	elif p != null:
		# Clicking an enemy just shows its card (to read its power).
		_clear_selection()
		hud.show_character(state, s, 0, false)
		board.highlight_square(s, Color(1, 1, 1, 0.25))
	else:
		_clear_selection()


func _select(s: int) -> void:
	var state := controller.state
	_selected = s
	_selected_actions = Rules.legal_actions_from(state, s)
	_mode = Mode.SELECTED
	_draw_base_highlights(state)
	board.highlight_square(s, Style.HL_SELECTED)
	var power_targets := 0
	for a in _selected_actions:
		if a.is_move():
			if state.piece_at(a.to) != null or (state.piece_at(s).kind == Chess.Kind.PAWN and a.to == state.ep_square):
				board.highlight_ring(a.to, Style.HL_CAPTURE)
			else:
				board.highlight_dot(a.to, Style.HL_MOVE)
		else:
			power_targets += 1
	hud.show_character(state, s, power_targets, false)
	hud.set_hint("")


func _on_power_pressed() -> void:
	if _mode != Mode.SELECTED:
		return
	var state := controller.state
	_mode = Mode.TARGETING
	_draw_base_highlights(state)
	board.highlight_square(_selected, Style.HL_SELECTED)
	var count := 0
	for a in _selected_actions:
		if a.type == GameAction.Type.ABILITY:
			board.highlight_ring(a.to, Style.HL_ABILITY)
			count += 1
	hud.show_character(state, _selected, count, true)
	hud.set_hint(Texts.CHOOSE_TARGET)


func _on_promotion_chosen(kind: int) -> void:
	for a in _pending_promotion:
		if a.promotion == kind:
			_pending_promotion = []
			_mode = Mode.IDLE
			controller.submit_action(a)
			return


func _clear_selection() -> void:
	_selected = -1
	_selected_actions = []
	if _mode != Mode.BUSY:
		_mode = Mode.IDLE
	hud.hide_character()
	hud.set_hint("")
	if controller != null and controller.state != null:
		_draw_base_highlights(controller.state)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_clear_selection()
	elif event.is_action_pressed("ui_cancel"):
		_clear_selection()
