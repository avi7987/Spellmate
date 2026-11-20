class_name Voice
extends RefCounted
## Funny gibberish "voices": every character mumbles a few syllables in its
## own pitch (the giant is deep, the miner squeaky, the assassin whispers).

const PITCH := {
	"king": 0.8, "queen": 1.25, "miner": 1.6, "soldier": 1.15, "archer": 1.3, "shield": 0.75,
	"knight": 1.0, "healer": 1.45, "ice_witch": 1.35, "fire_mage": 0.9, "assassin": 1.1,
	"giant": 0.55, "ballista": 0.95, "dragon": 0.6,
}

static var volume := 0.7


static func babble(kind: String, syllables: int = -1) -> void:
	if volume <= 0.0 or DisplayServer.get_name() == "headless":
		return
	var tree := Engine.get_main_loop() as SceneTree
	var n := syllables if syllables > 0 else randi_range(3, 6)
	var base: float = PITCH.get(kind, 1.0)
	var gain := 0.45 if kind == "assassin" else 0.9
	for i in n:
		Sfx._last.erase("voice")
		var s := "voice_%d" % (randi() % 10)
		Sfx._last.erase(s)
		Sfx.play(s, gain * volume, base * randf_range(0.9, 1.15))
		await tree.create_timer(randf_range(0.09, 0.14)).timeout
