class_name Sfx
extends RefCounted
## Plays a short sound effect by name (files in res://assets/audio/, made by
## tools/make_sounds.py). Sfx.play("boom") from anywhere.

static var volume := 0.8
static var _pool: Array = []
static var _cache: Dictionary = {}
static var _last: Dictionary = {}


static func _stream(name: String) -> AudioStream:
	if not _cache.has(name):
		var path := "res://assets/audio/%s.wav" % name
		_cache[name] = load(path) if ResourceLoader.exists(path) else null
	return _cache[name]


static func _player() -> AudioStreamPlayer:
	for p: AudioStreamPlayer in _pool:
		if is_instance_valid(p) and not p.playing:
			return p
	if _pool.size() >= 14:
		return _pool[0]
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return null
	var p := AudioStreamPlayer.new()
	tree.root.add_child.call_deferred(p)
	_pool.append(p)
	return p


## gain: 0..1. The same sound is not repeated more than ~12 times a second.
static func play(name: String, gain: float = 1.0, pitch: float = 1.0) -> void:
	if volume <= 0.0 or DisplayServer.get_name() == "headless":
		return
	var now := Time.get_ticks_msec()
	if now - int(_last.get(name, 0)) < 80:
		return
	_last[name] = now
	var s := _stream(name)
	var p := _player()
	if s == null or p == null:
		return
	p.stream = s
	p.volume_db = linear_to_db(maxf(0.001, gain * volume))
	p.pitch_scale = pitch * randf_range(0.95, 1.05)
	if p.is_inside_tree():
		p.play()
	else:
		if not p.ready.is_connected(p.play):
			p.ready.connect(p.play, CONNECT_ONE_SHOT)
