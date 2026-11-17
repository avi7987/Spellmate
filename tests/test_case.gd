class_name TestCase
extends RefCounted
## Base class for test files: provides assert helpers.

var failures: Array = []


func check(condition: bool, message: String = "condition was false") -> void:
	if not condition:
		failures.append(message)


func check_eq(actual, expected, message: String = "") -> void:
	if actual != expected:
		failures.append("%s expected <%s> but got <%s>" % [message, str(expected), str(actual)])


## Helper: find a legal action by its text, e.g. "e2e4", "e7e8q" or "frost:d1>d7".
func find_action(state: GameState, text: String) -> GameAction:
	for a in Rules.legal_actions(state):
		if str(a) == text:
			return a
	return null


## Plays a list of actions; records a failure if one is illegal.
func play(state: GameState, actions: Array) -> void:
	for text in actions:
		var a := find_action(state, text)
		if a == null:
			failures.append("illegal action in sequence: " + text)
			return
		Rules.apply_action(state, a)
