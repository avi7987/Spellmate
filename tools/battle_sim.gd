extends SceneTree
## Computer vs computer real-time battles, no graphics.
## godot --headless --script res://tools/battle_sim.gd -- [size] [games] [levelA] [levelB] [mode]

const DECK := ["soldier", "archer", "miner", "knight", "shield", "fire_mage", "ice_bomb", "fire_bomb"]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var size := a[0] if a.size() > 0 else "small"
	var games := int(a[1]) if a.size() > 1 else 4
	var la := int(a[2]) if a.size() > 2 else 2
	var lb := int(a[3]) if a.size() > 3 else 2
	var mode := a[4] if a.size() > 4 else "mate"
	var wins := [0, 0, 0]
	var t0 := Time.get_ticks_msec()
	for g in games:
		var b := Battle.create(size, [DECK, DECK], [{}, {}], (int(a[5]) if a.size() > 5 else 11) + g, "meadow", mode)
		var ais := [BattleAI.new(0, la), BattleAI.new(1, lb)]
		ais[0]._rng.seed = 100 + g
		ais[1]._rng.seed = 7777 + g * 13
		var stats := { "spawn": 0, "death": 0, "ability": 0, "spell": 0, "energy": 0, "check": 0, "crown_taken": 0, "rune_home": 0, "throne": 0 }
		var reason := ""
		var turn_n := 0
		while not b.is_over():
			# simultaneous turns: both plan, then 5 seconds of action
			# alternate who plans first (the second planner sees the first one's new heroes)
			turn_n += 1
			var order := ais if turn_n % 2 == 0 else [ais[1], ais[0]]
			for ai in order:
				ai.plan_turn(b)
			for i in 50:
				b.step(0.1)
			for e in b.take_events():
				if e["type"] == "game_over":
					reason = e["reason"]
				if stats.has(e["type"]):
					stats[e["type"]] += 1
		wins[b.winner] += 1
		print("off=%d game %d: winner=%s (%s)  time=%ds  units left=%d  %s" % [b.sky_offset, g, ["Sun", "Void", "draw"][b.winner], reason, int(b.time), b.units.size(), stats])
	print("Sun %d  Void %d  draws %d   (%d ms)" % [wins[0], wins[1], wins[2], Time.get_ticks_msec() - t0])
	quit()
