extends SceneTree
## Developer tool: computer-vs-computer wars, prints result and speed.
##   godot --headless --script res://tools/simulate.gd

func _init():
	var ai := AiPlayer.new()
	for game in 2:
		var s := GameState.new_game(true, 200 + game)
		var t0 := Time.get_ticks_msec()
		var actions := 0
		var attacks := 0
		var recruits := 0
		var slowest := 0
		var turn_t := Time.get_ticks_msec()
		while s.winner < 0 and actions < 20000:
			var a := ai.choose_action(s, 1)
			actions += 1
			if a.type == GameAction.Type.ATTACK: attacks += 1
			if a.type == GameAction.Type.RECRUIT: recruits += 1
			Rules.apply_action(s, a)
			if a.type == GameAction.Type.END_TURN:
				slowest = maxi(slowest, Time.get_ticks_msec() - turn_t)
				turn_t = Time.get_ticks_msec()
		print("game ", game, ": winner=", s.winner, " turns=", s.ply, " actions=", actions, " attacks=", attacks,
			" recruits=", recruits, " gates=", s.structures.filter(func(x): return x["kind"] == "gate").size(),
			" units=", s.units_of(0).size(), "/", s.units_of(1).size(), " gate_hp=", s.structures.filter(func(x): return x["kind"] == "gate").map(func(x): return x["hp"]),
			" time=", (Time.get_ticks_msec() - t0) / 1000.0, "s slowest turn=", slowest, "ms")
	quit()
