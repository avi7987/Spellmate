class_name Portraits
extends Node
## Takes a small picture of every hero (for cards and buttons) by rendering its
## 3D model in a hidden mini-scene. Pictures are cached for the whole game.

static var cache: Dictionary = {}


static func get_tex(id: String, team: int = 0) -> Texture2D:
	return cache.get("%s_%d" % [id, team], null)


## Renders the pictures that are still missing (a few frames each).
func render(ids: Array, team: int = 0, size: int = 192) -> void:
	var todo := ids.filter(func(id): return not cache.has("%s_%d" % [id, team]) and not BattleData.is_spell(id))
	if todo.is_empty():
		return
	var vp := SubViewport.new()
	vp.size = Vector2i(size, size)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.7, 0.65)
	env.environment.ambient_light_energy = 0.7
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	vp.add_child(env)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-35, 25, 0)
	light.light_energy = 1.1
	vp.add_child(light)
	var cam := Camera3D.new()
	cam.fov = 30
	vp.add_child(cam)
	for id in todo:
		var m := PieceModelFactory.build_hero(id, team)
		vp.add_child(m)
		var player: AnimationPlayer = (m.get_meta("player") if m.has_meta("player") else null)
		var anims: Dictionary = m.get_meta("anims", {})
		if player != null and anims.has("idle") and player.has_animation(anims["idle"]):
			player.play(anims["idle"])
			player.seek(0.3, true)
		await get_tree().process_frame
		var box := _bounds(m)
		var top := box.end.y
		var focus := Vector3(0, top - box.size.y * 0.32, 0)
		var dist := maxf(box.size.y * 0.6, maxf(box.size.x, box.size.z) * 0.75) * 2.6 + 0.4
		cam.position = focus + Vector3(0.35, 0.25, 1.0).normalized() * dist
		cam.look_at(focus)
		await get_tree().process_frame
		await get_tree().process_frame
		var img := vp.get_texture().get_image()
		cache["%s_%d" % [id, team]] = ImageTexture.create_from_image(img)
		m.queue_free()
	vp.queue_free()


static func _bounds(n: Node3D) -> AABB:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		if not mi.is_visible_in_tree():
			continue
		var b: AABB = mi.global_transform * mi.get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box
