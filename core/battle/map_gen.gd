class_name MapGen
extends RefCounted
## Builds a battle map: grass, forests, hills, a river with bridges, crystal
## mines and a walled palace for each kingdom (gate + two towers, king inside).
## The map is point-symmetric (turned 180 degrees it looks the same), so it is
## fair for both sides. Sizes: small / medium / large (data/battle.json).

## Returns { w, h, fog, terrain: PackedInt32Array, mines: [Vector2i],
##           palaces: [ { gate, towers: [a, b], king, spawn, floor: Rect2i } for team 0 and 1 ] }
static func make(size: String, seed_value: int = 7) -> Dictionary:
	var info: Dictionary = BattleData.cfg()["maps"][size]
	var w := int(info["w"])
	var h := int(info["h"])
	var t := PackedInt32Array()
	t.resize(w * h)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var cx := (w - 1) / 2
	var mid := (h - 1) / 2
	var put := func(x: int, y: int, v: int) -> void:
		if x >= 0 and x < w and y >= 0 and y < h:
			t[y * w + x] = v
	# Palace of the Sun (bottom). Floor cx-3..cx+3, rows 0..3; front wall on row 4.
	for y in 5:
		for x in range(cx - 4, cx + 5):
			var wall := x == cx - 4 or x == cx + 4 or y == 4
			put.call(x, y, Chess.Terrain.WALL if wall else Chess.Terrain.CASTLE)
	put.call(cx, 4, Chess.Terrain.CASTLE)   # the gate square
	# Forests and hills on the Sun half (mirrored later), away from the palace road.
	var blobs := maxi(3, w * h / 120)
	for i in blobs:
		var bx := rng.randi_range(1, w - 2)
		var by := rng.randi_range(6, mid - 2)
		if absi(bx - cx) <= 1:
			continue
		var kind := Chess.Terrain.FOREST if rng.randf() < 0.65 else Chess.Terrain.HILL
		for j in rng.randi_range(2, 5):
			var x := bx + rng.randi_range(-1, 1)
			var y := by + rng.randi_range(-1, 1)
			if y > 5 and y < mid and absi(x - cx) > 1:
				put.call(x, y, kind)
	# Crystal mines: two near the palace, one contested near the river.
	var mines_half := [Vector2i(2, 6), Vector2i(w - 3, 6), Vector2i(maxi(2, cx - 5), mid - 2)]
	for m in mines_half:
		put.call(m.x, m.y, Chess.Terrain.MINE)
	# Mirror the bottom half onto the top half.
	for y in mid:
		for x in w:
			t[(h - 1 - y) * w + (w - 1 - x)] = t[y * w + x]
	# The river in the middle row(s) with bridges.
	var river_rows := [mid] if h % 2 == 1 else [mid, mid + 1]
	var bridges := [2, w - 3]
	if w >= 19:
		bridges.append(cx)
	for y in river_rows:
		for x in w:
			t[y * w + x] = Chess.Terrain.BRIDGE if bridges.has(x) else Chess.Terrain.WATER
	var mines := []
	for m in mines_half:
		mines.append(m)
		mines.append(Vector2i(w - 1 - m.x, h - 1 - m.y))
	var sun := { "gate": Vector2i(cx, 4), "towers": [Vector2i(cx - 4, 4), Vector2i(cx + 4, 4)],
		"king": Vector2i(cx, 1), "spawn": Vector2i(cx, 5), "floor": Rect2i(cx - 3, 0, 7, 4) }
	var flip := func(v: Vector2i) -> Vector2i: return Vector2i(w - 1 - v.x, h - 1 - v.y)
	var void_ := { "gate": flip.call(sun["gate"]), "towers": [flip.call(sun["towers"][0]), flip.call(sun["towers"][1])],
		"king": flip.call(sun["king"]), "spawn": flip.call(sun["spawn"]),
		"floor": Rect2i(w - 1 - (cx + 3), h - 4, 7, 4) }
	return { "w": w, "h": h, "fog": bool(info.get("fog", false)), "terrain": t, "mines": mines,
		"palaces": [sun, void_], "size": size }
