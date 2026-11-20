extends SceneTree
## Computer vs computer real-time battles, no graphics.
## godot --headless --script res://tools/battle_sim.gd -- [size] [games] [levelA] [levelB]

const DECK := ["soldier", "archer", "miner", "knight", "shield", "fire_mage", "ice_bomb", "fire_bomb"]


func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var size := a[0] if a.size() > 0 else "small"
	var games := int(a[1]) if a.size() > 1 else 4
	var la := int(a[2]) if a.size() > 2 else 2
	var lb := int(a[3]) if a.size() > 3 else 2
	var wins := [0, 0, 0]
	var t0 := Time.get_ticks_msec()
	for g in games:
		var b := Battle.create(size, [DECK, DECK], [{}, {}], 11 + g)
		var ais := [BattleAI.new(0, la), BattleAI.new(1, lb)]
		ais[0]._rng.seed = 100 + g
		var stats := { "spawn": 0, "death": 0, "ability": 0, "spell": 0, "energy": 0, "breach": 0 }
		while not b.is_over():
			# simultaneous turns: both plan, then 5 seconds of action
			# alternate who plans first (the second planner sees the first one's new heroes)
			var order := ais if int(b.time / 5.0) % 2 == 0 else [ais[1], ais[0]]
			for ai in order:
				ai.plan_turn(b)
			for i in 50:
				b.step(0.1)
			for e in b.take_events():
				if stats.has(e["type"]):
					stats[e["type"]] += 1
		wins[b.winner] += 1
		print("game %d: winner=%s  time=%ds  units left=%d  %s" % [g, ["Sun", "Void", "draw"][b.winner], int(b.time), b.units.size(), stats])
	print("Sun %d  Void %d  draws %d   (%d ms)" % [wins[0], wins[1], wins[2], Time.get_ticks_msec() - t0])
	quit()
