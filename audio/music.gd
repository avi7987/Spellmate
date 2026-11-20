class_name Music
extends RefCounted
## Background music loops ("base", "battle") with a soft cross-fade.

static var volume := 0.45
static var _player: AudioStreamPlayer
static var _current := ""


static func play(name: String) -> void:
	if name == _current or DisplayServer.get_name() == "headless":
		return
	_current = name
	var path := "res://assets/audio/music_%s.wav" % name
	if not ResourceLoader.exists(path):
		return
	var tree := Engine.get_main_loop() as SceneTree
	if _player == null or not is_instance_valid(_player):
		_player = AudioStreamPlayer.new()
		tree.root.add_child.call_deferred(_player)
		await tree.process_frame
	var s := load(path) as AudioStreamWAV
	if s != null:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 2
	var tw := _player.create_tween()
	tw.tween_property(_player, "volume_db", -40.0, 0.4)
	tw.tween_callback(func():
		_player.stream = s
		_player.play())
	tw.tween_property(_player, "volume_db", linear_to_db(maxf(0.001, volume)), 0.8)


static func set_volume(v: float) -> void:
	volume = v
	if _player != null and is_instance_valid(_player):
		_player.volume_db = linear_to_db(maxf(0.001, v))
