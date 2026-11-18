extends SceneTree
## Developer tool: computer-vs-computer battles, prints result and speed.
##   godot --headless --script res://tools/simulate.gd
func _init():
	var ai := AiPlayer.new()
	for game in 2:
		var s := GameState.new_game(true, 100 + game)
		var t0 := Time.get_ticks_msec()
		var maxt := 0
		var battles := 0
		while s.winner < 0:
			var lvl := 1 if s.side_to_move == 0 else (2 if game == 2 else 1)
			var t := Time.get_ticks_msec()
			var a := ai.choose_action(s, lvl)
			maxt = maxi(maxt, Time.get_ticks_msec() - t)
			if Rules.is_attack(s, a): battles += 1
			Rules.apply_action(s, a)
		print("game ", game, ": winner=", s.winner, " plies=", s.ply, " battles=", battles, " units left=", s.all_pieces().size(), " total ", (Time.get_ticks_msec()-t0)/1000.0, "s, slowest move ", maxt, "ms")
	quit()
