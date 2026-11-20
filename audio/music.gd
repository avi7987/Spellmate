class_name Music
extends RefCounted
## Background music: "base" (village), "plan" (planning phase) and "battle"
## (action phase). Every track keeps playing quietly in the background once it
## has started, so switching between planning and action every turn is a soft
## cross-fade, not a restart. Music is made by tools/make_music.py.

static var volume := 0.45
static var _players: Dictionary = {}   ## name -> AudioStreamPlayer
static var _current := ""


static func play(name: String) -> void:
	if name == _current or DisplayServer.get_name() == "headless":
		return
	_current = name
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return
	if not _players.has(name) or not is_instance_valid(_players[name]):
		var path := "res://assets/audio/music_%s.wav" % name
		if not ResourceLoader.exists(path):
			return
		var s := load(path) as AudioStreamWAV
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 2
		var p := AudioStreamPlayer.new()
		p.stream = s
		p.volume_db = -60.0
		tree.root.add_child.call_deferred(p)
		p.ready.connect(p.play, CONNECT_ONE_SHOT)
		_players[name] = p
	for key in _players:
		var p: AudioStreamPlayer = _players[key]
		if not is_instance_valid(p):
			continue
		var target := linear_to_db(maxf(0.001, volume)) if key == name else -60.0
		var tw := tree.create_tween()
		tw.tween_property(p, "volume_db", target, 0.8 if key == name else 1.2)


static func set_volume(v: float) -> void:
	volume = v
	if _players.has(_current) and is_instance_valid(_players[_current]):
		_players[_current].volume_db = linear_to_db(maxf(0.001, v))
