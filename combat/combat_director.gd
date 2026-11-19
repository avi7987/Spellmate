class_name CombatDirector
extends Node
## Plays an attack. The GameState already knows the result (damage, counter,
## deaths); here we only show it:
##   - FULL: cut to the cinematic BattleArena (skippable)
##   - QUICK: a short fight on the map (step in, strike, numbers fly)
## Which one is used follows the player's setting (Hud.scene_mode):
## always / important battles only (kings, queens, dragons, giants, a kill) / never.

signal combat_started
signal combat_finished

var board: BoardView
var camera_rig: CameraRig
var hud: Hud
var arena: BattleArena

const IMPORTANT := [Chess.Kind.KING, Chess.Kind.QUEEN, Chess.Kind.DRAGON, Chess.Kind.GIANT]


func _ready() -> void:
	arena = BattleArena.new()
	add_child(arena)


func skip() -> void:
	if arena != null:
		arena.skip()


func _wants_scene(e: Dictionary) -> bool:
	if hud == null or not e.has("defender_id"):
		return false   # gates and towers are always fought on the map
	match hud.scene_mode:
		0:
			return true
		2:
			return false
	return IMPORTANT.has(e["attacker_kind"]) or IMPORTANT.has(e["defender_kind"]) \
		or int(e["defender_hp"]) <= 0 or int(e["attacker_hp"]) <= 0


func play_battle(e: Dictionary, attacker: PieceView, defender: Node3D, from_pos: Vector3, to_pos: Vector3, terrain: int) -> void:
	combat_started.emit()
	# Fights hidden in the fog of war are not shown.
	var seen := (attacker != null and attacker.visible) or (defender != null and defender.visible)
	if not seen:
		combat_finished.emit()
		return
	if _wants_scene(e) and attacker != null:
		await arena.play(e, terrain, attacker.color, hud)
		camera_rig.make_current()
		await hud.fade(0.0, 0.3)
		combat_finished.emit()
		return
	# QUICK: a short fight on the map.
	if attacker != null:
		var ranged: bool = e.get("ranged", false)
		if not ranged:
			await attacker.move_to(from_pos.lerp(to_pos, 0.4), 0.2, false)
		await attacker.play_action("attack", 0.45)
		if ranged:
			await _bolt(from_pos + Vector3(0, 0.8, 0), to_pos + Vector3(0, 0.6, 0), Style.team(attacker.color)["ui"])
	Effects.burst(board, to_pos + Vector3(0, 0.5, 0), Color(1.0, 0.85, 0.3), 20, 3.0)
	board._float_text(to_pos, str(e["damage"]), Color(1.0, 0.85, 0.4))
	if defender is PieceView and int(e.get("defender_hp", 1)) > 0:
		defender.play_action("hit", 0.4)
		(defender as PieceView).set_health(int(e["defender_hp"]), maxi(1, int(e.get("defender_hp_before", 1))))
	if camera_rig != null:
		camera_rig.shake(0.06, 0.2)
	if int(e.get("counter", 0)) > 0 and attacker != null:
		await get_tree().create_timer(0.25).timeout
		if defender is PieceView:
			defender.play_action("attack", 0.4)
		Effects.burst(board, attacker.position + Vector3(0, 0.5, 0), Color(1.0, 0.6, 0.3), 14, 2.5)
		board._float_text(attacker.position, str(e["counter"]), Color(1.0, 0.45, 0.35))
	if attacker != null and not e.get("ranged", false):
		await attacker.move_to(from_pos, 0.2, false)
	combat_finished.emit()


func _bolt(from: Vector3, to: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var sp := SphereMesh.new()
	sp.radius = 0.08
	sp.height = 0.16
	mi.mesh = sp
	mi.material_override = Style.glow(color, 2.5)
	mi.position = from
	board.add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "position", to, 0.25)
	await tw.finished
	mi.queue_free()
