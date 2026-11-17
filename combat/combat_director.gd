class_name CombatDirector
extends Node
## Plays the cinematic battle when one piece captures another.
##
## The battle is presentation only: the capture has ALREADY happened in the
## GameState. When the battle ends, the board is shown exactly as it was.
##
## Phase 1 (now): a quick on-board impact (flash, sparks, small camera shake).
## Phase 4 (roadmap): switch to a separate 3D arena scene with a perspective
## camera, full-size characters and attack/hit/defeat animations, then return.
## Only play_capture() needs to change - the rest of the game already waits for it.

signal combat_started
signal combat_finished

enum Mode { FULL, QUICK, OFF }

var mode: int = Mode.QUICK
var board: BoardView
var camera_rig: CameraRig


func play_capture(attacker: PieceView, victim: PieceView, at: Vector3) -> void:
	combat_started.emit()
	if mode != Mode.OFF and victim != null:
		if attacker != null:
			attacker.bounce()
		Effects.square_flash(board, at, Color(1, 1, 1, 0.8), 0.3)
		Effects.burst(board, at + Vector3(0, 0.4, 0), Color(1.0, 0.85, 0.3), 26, 3.0)
		Effects.ring(board, at, Color(1, 0.6, 0.2, 0.9))
		if camera_rig != null:
			camera_rig.shake(0.08, 0.25)
		await victim.defeat()
	elif victim != null:
		victim.visible = false
	combat_finished.emit()
