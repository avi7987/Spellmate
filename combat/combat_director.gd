class_name CombatDirector
extends Node
## Plays a battle when one unit attacks another.
##
## The battle is presentation only: the GameState already knows the result
## (the dice were rolled in Rules). Here we show it:
##   1. the attacker steps forward,
##   2. the battle bar shows the win chance and the dice needle spins and lands,
##   3. the winner strikes, the loser falls (a Bishop that loses slips back home).
## Phase 4 (roadmap) can move this into a separate cinematic arena scene; the
## rest of the game only calls play_battle() and waits for it.

signal combat_started
signal combat_finished

enum Mode { FULL, QUICK, OFF }

var mode: int = Mode.FULL
var board: BoardView
var camera_rig: CameraRig
var hud: Hud


func play_battle(e: Dictionary, attacker: PieceView, defender: PieceView, from_pos: Vector3, to_pos: Vector3) -> void:
	combat_started.emit()
	var won: bool = e["won"]
	if attacker != null:
		# Step halfway toward the enemy.
		await attacker.move_to(from_pos.lerp(to_pos, 0.45), 0.28, false)
	if hud != null and mode == Mode.FULL:
		await hud.play_battle_bar(e)
	if attacker != null:
		await attacker.play_action("attack", 0.5)
	Effects.square_flash(board, to_pos if won else from_pos, Color(1, 1, 1, 0.8), 0.3)
	Effects.burst(board, (to_pos if won else from_pos) + Vector3(0, 0.4, 0), Color(1.0, 0.85, 0.3), 26, 3.0)
	if camera_rig != null:
		camera_rig.shake(0.08, 0.25)
	if won:
		if defender != null:
			if e["defender_kind"] == Chess.Kind.KING:
				await defender.fall()
			else:
				await defender.defeat()
		if attacker != null:
			await attacker.move_to(to_pos, 0.22, false)
	else:
		if defender != null:
			defender.play_action("attack", 0.4)
		if attacker != null:
			if e["phased"]:
				Effects.burst(board, attacker.position + Vector3(0, 0.5, 0), Style.power_color("swap"), 24, 2.0)
				await attacker.move_to(from_pos, 0.25, true)
			elif e["attacker_kind"] == Chess.Kind.KING:
				await attacker.fall()
			else:
				await attacker.defeat()
	combat_finished.emit()
