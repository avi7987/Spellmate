class_name MapGen
extends RefCounted
## Builds a battle map: grass, forests, hills, a river with bridges, crystal
## mines and a walled palace for each kingdom (gate + two towers, king inside).
## The map is point-symmetric (turned 180 degrees it looks the same), so it is
## fair for both sides. Sizes: small / medium / large (data/battle.json).

## Every world (data/biomes.json) also gets patches of its special ground (mud,
## lava, ice, sand, candy, spores), small lakes, shrines with powers and two
## monster camps - always mirrored, so both sides get the same.
##
## Returns { w, h, fog, biome, terrain: PackedInt32Array, mines: [Vector2i],
##           shrines: [ { pos, type } ], camps: [Vector2i],
##           palaces: [ { gate, towers: [a, b], king, spawn, floor: Rect2i } for team 0 and 1 ] }
static func make(size: String, seed_value: int = 7, biome: String = "meadow") -> Dictionary:
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
	# The world's special ground in a few patches.
	for i in maxi(2, w * h / 140):
		var bx := rng.randi_range(1, w - 2)
		var by := rng.randi_range(6, mid - 1)
		for j in rng.randi_range(3, 6):
			var x := bx + rng.randi_range(-1, 1)
			var y := by + rng.randi_range(-1, 1)
			if y > 5 and y < mid and absi(x - cx) > 0:
				put.call(x, y, Chess.Terrain.SPECIAL)
	# Small lakes (removed again below if they would block a road).
	var lakes := []
	for i in maxi(1, w * h / 260):
		var lx := rng.randi_range(2, w - 3)
		var ly := rng.randi_range(7, mid - 2)
		if absi(lx - cx) <= 2:
			continue
		var cells := [Vector2i(lx, ly)]
		for j in rng.randi_range(1, 3):
			cells.append(Vector2i(lx + rng.randi_range(-1, 1), ly + rng.randi_range(0, 1)))
		lakes.append(cells)
		for c in cells:
			put.call(c.x, c.y, Chess.Terrain.WATER)
	# Crystal mines: two near the palace, one contested near the river.
	var mines_half := [Vector2i(2, 6), Vector2i(w - 3, 6), Vector2i(maxi(2, cx - 5), mid - 2)]
	for m in mines_half:
		put.call(m.x, m.y, Chess.Terrain.MINE)
	# Shrines: a healing spring, a power stone and a magic well on each half.
	var shrines_half := [
		{ "pos": Vector2i(1, mid - 3), "type": "heal" },
		{ "pos": Vector2i(w - 2, mid - 3), "type": "power" },
		{ "pos": Vector2i(mini(w - 3, cx + 3), mid - 1), "type": "energy" },
	]
	for sh in shrines_half:
		put.call(sh["pos"].x, sh["pos"].y, Chess.Terrain.SHRINE)
	var camp_half := Vector2i(cx, mid - 2)
	put.call(camp_half.x, camp_half.y, Chess.Terrain.PLAIN)
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
	var shrines := []
	for sh in shrines_half:
		shrines.append(sh)
		shrines.append({ "pos": Vector2i(w - 1 - sh["pos"].x, h - 1 - sh["pos"].y), "type": sh["type"] })
	var camps := [camp_half, Vector2i(w - 1 - camp_half.x, h - 1 - camp_half.y)]
	# Lakes must never cut a road: if the two palaces or a mine cannot be reached, dry it up.
	var spawn_a := Vector2i(cx, 5)
	var targets := [Vector2i(w - 1 - cx, h - 6)] + mines + camps
	for cells in lakes:
		if _all_reachable(t, w, h, spawn_a, targets):
			break
		for c in cells:
			for cc in [c, Vector2i(w - 1 - c.x, h - 1 - c.y)]:
				if cc.x >= 0 and cc.y >= 0 and cc.x < w and cc.y < h and t[cc.y * w + cc.x] == Chess.Terrain.WATER and cc.y != mid and not (h % 2 == 0 and cc.y == mid + 1):
					t[cc.y * w + cc.x] = Chess.Terrain.PLAIN
	var sun := { "gate": Vector2i(cx, 4), "towers": [Vector2i(cx - 4, 4), Vector2i(cx + 4, 4)],
		"king": Vector2i(cx, 1), "spawn": Vector2i(cx, 5), "floor": Rect2i(cx - 3, 0, 7, 4) }
	var flip := func(v: Vector2i) -> Vector2i: return Vector2i(w - 1 - v.x, h - 1 - v.y)
	var void_ := { "gate": flip.call(sun["gate"]), "towers": [flip.call(sun["towers"][0]), flip.call(sun["towers"][1])],
		"king": flip.call(sun["king"]), "spawn": flip.call(sun["spawn"]),
		"floor": Rect2i(w - 1 - (cx + 3), h - 4, 7, 4) }
	return { "w": w, "h": h, "fog": bool(info.get("fog", false)), "terrain": t, "mines": mines,
		"palaces": [sun, void_], "size": size, "biome": biome, "shrines": shrines, "camps": camps }


## Can every target square be reached on foot from `from`?
static func _all_reachable(t: PackedInt32Array, w: int, h: int, from: Vector2i, targets: Array) -> bool:
	var seen := PackedByteArray()
	seen.resize(w * h)
	var queue := [from]
	seen[from.y * w + from.x] = 1
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= w or n.y >= h or seen[n.y * w + n.x] == 1:
				continue
			var k: int = t[n.y * w + n.x]
			if k == Chess.Terrain.WALL or k == Chess.Terrain.WATER:
				continue
			seen[n.y * w + n.x] = 1
			queue.append(n)
	for g in targets:
		if seen[g.y * w + g.x] == 0:
			return false
	return true
