extends SceneTree
## Developer tool: opens the game, optionally plays some actions, and saves a
## screenshot. Needs a real display (or xvfb-run). Example:
##   godot --script res://tools/screenshot.gd -- out.png "e2e4,e7e5" nomenu

var _out := "screenshot.png"
var _actions: Array = []
var _hide_menu := false
var _frames := 0
var _main: Node


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: _out = args[0]
	if args.size() > 1 and args[1] != "": _actions = Array(args[1].split(","))
	if args.size() > 2: _hide_menu = args[2] == "nomenu"
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 5:
		if _hide_menu:
			_main.hud.show_menu(false)
		var ui_steps := []
		for text in _actions:
			if text.begins_with("put:"):  # put:<kind>:<color 0/1>:<square>, e.g. put:rook:1:f7
				var parts: PackedStringArray = text.split(":")
				var st: GameState = _main.controller.state
				st.board[Chess.parse_square(parts[3])] = null
				st.add_piece(Chess.kind_from_name(parts[1]), int(parts[2]), Chess.parse_square(parts[3]))
				continue
			if text.begins_with("select:") or text == "power" or text == "battlebar" or text.begins_with("odds:"):
				ui_steps.append(text)
				continue
			for a in Rules.legal_actions(_main.controller.state):
				if str(a) == text:
					Rules.apply_action(_main.controller.state, a)
		_main.board.sync(_main.controller.state)
		_main._refresh(_main.controller.state)
		_main._apply_mood(_main.controller.state.side_to_move, false)
		for text in ui_steps:
			if text == "battlebar":  # show the battle bar frozen mid-roll
				var h = _main.hud
				h.set_last_mover(0)
				h._battle.visible = true
				h._battle_names.text = "%s  נגד  %s" % [Texts.character(Chess.Kind.KNIGHT, 0), Texts.character(Chess.Kind.ROOK, 1)]
				h._battle_bar.setup(65)
				h._battle_bar.needle = 41.5
				h._battle_result.text = Texts.VICTORY
				h._battle_result.add_theme_color_override("font_color", Color(0.45, 0.95, 0.45))
				continue
			if text.begins_with("odds:"):  # odds:<from>><to>
				var ft: PackedStringArray = text.substr(5).split(">")
				var st2: GameState = _main.controller.state
				var a2 := st2.piece_at(Chess.parse_square(ft[0]))
				var d2 := st2.piece_at(Chess.parse_square(ft[1]))
				_main.hud.show_odds(Combat.odds(st2, Chess.parse_square(ft[0]), Chess.parse_square(ft[1])),
					Texts.character(a2.kind, a2.color), Texts.character(d2.kind, d2.color))
				continue
			if text == "power":
				_main._on_power_pressed()
			else:
				_main._on_square_clicked(Chess.parse_square(text.substr(7)))
				var cam: Camera3D = _main.camera_rig.camera
				var sq := Chess.parse_square(text.substr(7))

	if _frames == 110:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false
