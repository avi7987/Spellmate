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

