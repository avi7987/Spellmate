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
		for text in _actions:
			if text.begins_with("select:"):
				_main._on_square_clicked(Chess.parse_square(text.substr(7)))
				continue
			if text == "power":
				_main._on_power_pressed()
				continue
			for a in Rules.legal_actions(_main.controller.state):
				if str(a) == text:
					var events := Rules.apply_action(_main.controller.state, a)
					_main.board.sync(_main.controller.state)
		_main._refresh(_main.controller.state)
	if _frames == 70:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(_out)
		print("saved ", _out)
		quit()
	return false
