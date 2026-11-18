class_name CombatDirector
extends Node
## Plays a battle when one unit attacks another.
##
## The battle is presentation only: the GameState already knows the result
## (the dice were rolled in Rules). FULL mode cuts to the cinematic BattleArena
## (6-8 seconds, skippable); QUICK mode shows a short fight on the board.

signal combat_started
signal combat_finished

enum Mode { FULL, QUICK }

var mode: int = Mode.FULL
var board: BoardView
var camera_rig: CameraRig
var hud: Hud
var arena: BattleArena


func _ready() -> void:
	arena = BattleArena.new()
	add_child(arena)


func skip() -> void:
	if arena != null:
		arena.skip()


func play_battle(e: Dictionary, attacker: PieceView, defender: PieceView, from_pos: Vector3, to_pos: Vector3, terrain: int) -> void:
	combat_started.emit()
	var won: bool = e["won"]
	if mode == Mode.FULL and hud != null and attacker != null:
		await arena.play(e, terrain, attacker.color, hud)
		camera_rig.make_current()
		# Show the board exactly as the battle ended.
		if won:
			if defender != null:
				defender.visible = false
			attacker.position = to_pos
		elif e["phased"]:
			attacker.position = from_pos
		else:
			attacker.visible = false
		await hud.fade(0.0, 0.3)
		if not won and e["phased"]:
			Effects.burst(board, from_pos + Vector3(0, 0.5, 0), Style.power_color("swap"), 24, 2.0)
		combat_finished.emit()
		return
	# QUICK: a short fight on the board.
	if attacker != null:
		await attacker.move_to(from_pos.lerp(to_pos, 0.45), 0.28, false)
		await attacker.play_action("attack", 0.5)
	Effects.burst(board, (to_pos if won else from_pos) + Vector3(0, 0.4, 0), Color(1.0, 0.85, 0.3), 26, 3.0)
	if camera_rig != null:
		camera_rig.shake(0.08, 0.25)
	if won:
		if defender != null:
			await defender.defeat()
		if attacker != null:
			await attacker.move_to(to_pos, 0.22, false)
	elif attacker != null:
		if e["phased"]:
			await attacker.move_to(from_pos, 0.25, true)
		else:
			await attacker.defeat()
	combat_finished.emit()
