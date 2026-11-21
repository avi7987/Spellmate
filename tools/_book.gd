extends SceneTree
## Opens every page of the hero book and every panel, looking for errors.
func _init():
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var app: Node = load("res://scenes/app.tscn").instantiate()
	root.add_child(app)
	await create_timer(4.0).timeout
	var base: BaseScreen = null
	for n in app.get_children():
		if n is BaseScreen: base = n
	for id in ["how"] + BattleData.hero_ids() + BattleData.spell_ids():
		print("page ", id)
		base._open(base._book_panel(id))
		await process_frame
		await process_frame
	for p in ["heroes", "deck", "chests", "quests", "world", "settings"]:
		print("panel ", p)
		base._open(base.call("_%s_panel" % p))
		await process_frame
	print("DONE")
	quit()
