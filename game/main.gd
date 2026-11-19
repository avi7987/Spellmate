extends Node3D
## Entry point: builds the scene (light, camera, world, HUD), connects the
## pieces together, and turns clicks into actions.
##
##   GameController  ── signals ──►  BoardView (3D)  +  Hud (2D)
##        ▲                                │
##        └──────── submit_action ◄── clicks, End turn, Recruit
##
## Playing a turn: click your unit -> green gems = where it can walk, red
## brackets = whom it can hit (with the expected damage). Walk first, then
## attack or use its power. Recruit new units at the gate. Then "End turn".

enum Mode { IDLE, SELECTED, TARGETING, BUSY }

var controller: GameController
var board: BoardView
var hud: Hud
var camera_rig: CameraRig
var combat: CombatDirector

var _env: Environment
var _sun: DirectionalLight3D
var _mode: int = Mode.IDLE
var _selected := -1
var _selected_actions: Array = []


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
	combat.hud = hud
	hud.battle_skip_pressed.connect(func(): combat.skip())
	hud.menu_toggled.connect(func(on): camera_rig.orbit_menu(on))

	controller.game_started.connect(_on_game_started)
	controller.action_applied.connect(_on_action_applied)
	controller.state_reset.connect(_on_state_reset)
	controller.ai_thinking.connect(func(on): hud.set_thinking(on))
	board.square_clicked.connect(_on_square_clicked)
	board.presentation_done.connect(_on_presentation_done)
	board.square_hovered.connect(_on_square_hovered)
	hud.new_game_requested.connect(func(vs_ai, powers, level): controller.new_game(vs_ai, powers, level))
	hud.undo_requested.connect(_on_undo)
	hud.power_pressed.connect(_on_power_pressed)
	hud.cancel_pressed.connect(_clear_selection)
	hud.end_turn_pressed.connect(_on_end_turn)
	hud.recruit_pressed.connect(_on_recruit)

	# Show the world behind the menu right away.
	controller.new_game(true, true, 1)
	hud.show_menu(true, false)


func _build_world() -> void:
	_env = Environment.new()
	_env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.25, 0.3, 0.45)
	sky_mat.sky_horizon_color = Color(0.6, 0.55, 0.5)
	sky_mat.ground_bottom_color = Color(0.15, 0.13, 0.1)
	sky_mat.ground_horizon_color = Color(0.45, 0.4, 0.35)
	sky_mat.energy_multiplier = 0.3
	sky.sky_material = sky_mat
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	_env.glow_enabled = true
	_env.glow_intensity = 0.35
	_env.glow_hdr_threshold = 1.1
	var we := WorldEnvironment.new()
	we.environment = _env
	add_child(we)
	_sun = DirectionalLight3D.new()
	_sun.rotation_degrees = Vector3(-58, 30, 0)
	_sun.shadow_enabled = true
	_sun.directional_shadow_max_distance = 45.0
	add_child(_sun)
	_apply_mood(Chess.WHITE, false)


## The scene's light follows whose turn it is: warm sunlight for the Sun,
## cold purple moonlight for the Void.
func _apply_mood(color: int, animate: bool = true) -> void:
	var m: Dictionary = Style.MOOD[color]
	if not animate:
		_sun.light_color = m["sun"]
		_sun.light_energy = m["sun_energy"]
		_env.ambient_light_color = m["ambient"]
		_env.ambient_light_energy = m["ambient_energy"]
		return
	var tw := create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
	tw.tween_property(_sun, "light_color", m["sun"], 0.9)
	tw.tween_property(_sun, "light_energy", m["sun_energy"], 0.9)
	tw.tween_property(_env, "ambient_light_color", m["ambient"], 0.9)
	tw.tween_property(_env, "ambient_light_energy", m["ambient_energy"], 0.9)
	board.set_turn_accent(m["accent"])


## The fog shows what the human sees: in a local game, the side to move.
func _viewer(state: GameState) -> int:
	if controller.is_vs_ai():
		return Chess.WHITE if controller.players[Chess.WHITE] == GameController.PlayerType.HUMAN else Chess.BLACK
	return state.side_to_move


# ------------------------------------------------------------ game events

func _on_game_started(state: GameState) -> void:
	_clear_selection()
	board.viewer = _viewer(state)
	board.sync(state)
	_apply_mood(state.side_to_move)
	_look_at_home(state, false)
	_refresh(state)


func _look_at_home(state: GameState, animate: bool) -> void:
	var color := _viewer(state)
	var gate := state.gate_of(color)
	var spot: int = int(gate["square"]) if not gate.is_empty() else state.find_king(color)
	if spot >= 0:
		var p := BoardView.square_xz(spot)
		camera_rig.look_at_point(p + Vector3(0, 0, -1.0 if color == Chess.WHITE else 1.0), animate)


func _on_action_applied(action: GameAction, events: Array, state: GameState) -> void:
	_mode = Mode.BUSY
	controller.busy = true
	board.clear_highlights()
	hud.hide_odds()
	if action.type != GameAction.Type.MOVE:
		hud.hide_character()
	board.play_events(events, state)


func _on_presentation_done() -> void:
	var state := controller.state
	var viewer := _viewer(state)
	if viewer != board.viewer:
		board.viewer = viewer
		board.sync(state)
		_look_at_home(state, true)
	_apply_mood(state.side_to_move)
	_mode = Mode.IDLE
	_refresh(state)
	if controller.is_over():
		await _play_game_end()
	elif _selected >= 0 and state.piece_at(_selected) != null and state.piece_at(_selected).color == state.side_to_move \
			and controller.is_human_turn():
		# Keep the unit selected after it walked, so it can attack next.
		_select(_selected)
	controller.on_presentation_done()


## The king fell: the winners cheer, then the result screen.
func _play_game_end() -> void:
	var r := controller.result
	if r["reason"] == "king":
		hud.flash(Texts.KING_FELL, Color(1.0, 0.3, 0.2))
		await board.play_victory(controller.state, controller.state.winner)
	else:
		await get_tree().create_timer(0.6).timeout
	hud.show_game_over(r)


func _on_state_reset(state: GameState) -> void:
	_clear_selection()
	board.viewer = _viewer(state)
	board.sync(state)
	_apply_mood(state.side_to_move)
	_refresh(state)


func _on_undo() -> void:
	if _mode != Mode.BUSY:
		controller.undo()


func _on_end_turn() -> void:
	if _mode == Mode.BUSY or not controller.is_human_turn():
		return
	_clear_selection()
	_selected = -1
	controller.submit_action(GameAction.end_turn())


func _on_recruit(kind: int) -> void:
	if _mode == Mode.BUSY or not controller.is_human_turn():
		return
	var state := controller.state
	var spots := Rules.spawn_squares(state, state.side_to_move)
	if spots.is_empty():
		hud.set_hint(Texts.NO_SPAWN)
		return
	# Prefer the free square in front of the gate (toward the enemy).
	var best: int = spots[0]
	for s in spots:
		var fwd := Chess.rank_of(s) if state.side_to_move == Chess.WHITE else -Chess.rank_of(s)
		var bfwd := Chess.rank_of(best) if state.side_to_move == Chess.WHITE else -Chess.rank_of(best)
		if fwd > bfwd:
			best = s
	controller.submit_action(GameAction.recruit(kind, best))


func _refresh(state: GameState) -> void:
	hud.update_state(state, controller)
	_draw_base_highlights(state)


func _draw_base_highlights(state: GameState) -> void:
	board.clear_highlights()
	# Your units that can still act get a soft glow, so you see who is left.
	if controller.is_human_turn():
		for s in state.units_of(state.side_to_move):
			var p := state.piece_at(s)
			if not p.acted and not state.is_frozen(p):
				board.mark(s, BoardView.Mark.LAST, Style.HL_LAST)
	var k := state.find_king(state.side_to_move)
	if k >= 0:
		for s in state.units_of(Chess.other(state.side_to_move)):
			if Chess.distance(s, k) <= 2:
				board.mark(k, BoardView.Mark.CHECK, Style.HL_CHECK)
				break


# ------------------------------------------------------------ clicking

## `s` = the unit clicked (or the ground square), `ground` = the square under the cursor.
func _on_square_clicked(s: int, ground: int = -1) -> void:
	if ground < 0:
		ground = s
	if _mode == Mode.BUSY or not controller.is_human_turn():
		return
	var state := controller.state
	if _mode == Mode.TARGETING:
		for target in [ground, s]:
			for a in _selected_actions:
				if a.type == GameAction.Type.ABILITY and a.to == target:
					controller.submit_action(a)
					return
		_clear_selection()
		return
	if _mode == Mode.SELECTED:
		# Attack: a click on an enemy (its body or its square). Move: the ground square.
		for a in _selected_actions:
			if a.type == GameAction.Type.ATTACK and (a.to == s or a.to == ground):
				controller.submit_action(a)
				return
		for a in _selected_actions:
			if a.is_move() and a.to == ground:
				_selected = a.to
				controller.submit_action(a)
				return
	var p := state.piece_at(s)
	if p != null and p.color == state.side_to_move:
		_select(s)
	elif p != null and board.is_visible_square(s):
		_clear_selection()
		hud.show_character(state, s, 0, false)
		board.mark(s, BoardView.Mark.SELECTED, Color(1.0, 0.4, 0.3, 0.6))
	else:
		_clear_selection()


func _select(s: int) -> void:
	var state := controller.state
	_selected = s
	_selected_actions = Rules.legal_actions_from(state, s)
	_mode = Mode.SELECTED
	_draw_base_highlights(state)
	board.mark(s, BoardView.Mark.SELECTED, Style.HL_SELECTED)
	var power_targets := 0
	for a in _selected_actions:
		match a.type:
			GameAction.Type.MOVE:
				board.mark(a.to, BoardView.Mark.MOVE, Style.HL_MOVE)
			GameAction.Type.ATTACK:
				var pv := Combat.preview(state, a.from, a.to)
				board.mark(a.to, BoardView.Mark.CAPTURE, Style.HL_CAPTURE)
				board.mark_text(a.to, "-%d" % pv["damage"], Color(0.5, 1.0, 0.5) if pv["kills"] else Color(1.0, 0.85, 0.4))
			GameAction.Type.ABILITY:
				power_targets += 1
	hud.show_character(state, s, power_targets, false)
	hud.set_hint("")


## Hovering an attack target shows the expected damage and counter-attack.
func _on_square_hovered(s: int) -> void:
	if _mode != Mode.SELECTED or s < 0:
		hud.hide_odds()
		return
	var state := controller.state
	for a in _selected_actions:
		if a.type == GameAction.Type.ATTACK and a.to == s:
			var att := state.piece_at(a.from)
			var def := state.piece_at(a.to)
			var def_name := Texts.character(def.kind, def.color) if def != null else \
				(Texts.GATE if state.structure_at(a.to).get("kind", "") == "gate" else Texts.TOWER)
			hud.show_preview(Texts.character(att.kind, att.color), def_name, Combat.preview(state, a.from, a.to))
			return
	hud.hide_odds()


func _on_power_pressed() -> void:
	if _mode != Mode.SELECTED:
		return
	var state := controller.state
	_mode = Mode.TARGETING
	_draw_base_highlights(state)
	board.mark(_selected, BoardView.Mark.SELECTED, Style.HL_SELECTED)
	var count := 0
	for a in _selected_actions:
		if a.type == GameAction.Type.ABILITY:
			board.mark(a.to, BoardView.Mark.POWER, Style.power_color(a.ability_id))
			count += 1
	hud.show_character(state, _selected, count, true)
	hud.set_hint(Texts.CHOOSE_TARGET)


func _clear_selection() -> void:
	_selected = -1
	_selected_actions = []
	if _mode != Mode.BUSY:
		_mode = Mode.IDLE
	hud.hide_character()
	hud.hide_odds()
	hud.set_hint("")
	if controller != null and controller.state != null:
		_draw_base_highlights(controller.state)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_clear_selection()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_SPACE, KEY_ENTER]:
		_on_end_turn()
