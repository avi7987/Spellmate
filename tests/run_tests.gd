extends SceneTree
## Minimal test runner. Run from the project folder:
##   godot --headless --script res://tests/run_tests.gd
## Every method whose name starts with "test_" in every tests/test_*.gd file is run.
## Exit code 0 = all passed, 1 = something failed.

const TEST_DIR := "res://tests/"


func _init() -> void:
	var files := []
	for f in DirAccess.get_files_at(TEST_DIR):
		if f.begins_with("test_") and f.ends_with(".gd"):
			files.append(f)
	files.sort()
	var passed := 0
	var failed := 0
	var start := Time.get_ticks_msec()
	for f in files:
		var script: GDScript = load(TEST_DIR + f)
		var suite: TestCase = script.new()
		for m in suite.get_method_list():
			var name: String = m["name"]
			if not name.begins_with("test_"):
				continue
			suite.failures.clear()
			var t0 := Time.get_ticks_msec()
			suite.call(name)
			var ms := Time.get_ticks_msec() - t0
			if suite.failures.is_empty():
				passed += 1
				print("  PASS  %s.%s (%d ms)" % [f.get_basename(), name, ms])
			else:
				failed += 1
				print("  FAIL  %s.%s" % [f.get_basename(), name])
				for msg in suite.failures:
					print("        - " + msg)
	print("\n%d passed, %d failed (%.1f s)" % [passed, failed, (Time.get_ticks_msec() - start) / 1000.0])
	quit(1 if failed > 0 else 0)
