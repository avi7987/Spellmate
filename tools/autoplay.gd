extends SceneTree
## Developer tool: plays a scripted game through the real UI path (clicks on
## squares) and reports what happened. Usage:
##   godot --headless --script res://tools/autoplay.gd -- local "f2,f3,e7,e5,g2,g4,d8,h4"
## Mode "local" = two players, "ai" = vs computer (only white clicks are scripted).

var _main: Node
var _clicks: Array = []
var _i := 0
var _wait := 0
var _frames := 0
var _vs_ai := false


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	_vs_ai = args.size() > 0 and args[0] == "ai"
	if args.size() > 1:
		_clicks = Array(args[1].split(","))
	_main = load("res://scenes/main.tscn").instantiate()
	root.add_child(_main)


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames == 3:
		_main.hud.show_menu(false)
		_main.controller.new_game(_vs_ai, true, 0)
	if _frames < 10:
		return false
	if _frames > 6000:
		print("TIMEOUT mode=", _main._mode, " busy=", _main.controller.busy)
		quit(1)
		return false
	if _wait > 0:
		_wait -= 1
		return false
	var c: GameController = _main.controller
	if c.is_over():
		if not _main.hud._over.visible:
			return false  # wait for the end-of-game sequence
		print("GAME OVER: ", c.result, "  overlay visible=", _main.hud._over.visible, " frames=", _frames)
		quit()
		return false
	if not c.is_human_turn() or _main._mode == _main.Mode.BUSY:
		return false
	if _i >= _clicks.size():
		print("DONE clicks. fen=", c.state.to_fen(), " mode=", _main._mode)
		quit()
		return false
	var sq := Chess.parse_square(_clicks[_i])
	print("click ", _clicks[_i], " (mode ", _main._mode, ", side ", c.state.side_to_move, ")")
	_main._on_square_clicked(sq)
	_i += 1
	_wait = 5
	return false
