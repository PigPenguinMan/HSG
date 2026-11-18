extends SceneTree
## Headless test entry point:
##   godot --headless --path . --script res://tests/run_tests.gd
## Exit code 0 = all passed, 1 = at least one check failed.

const T := preload("res://tests/test_check.gd")
const SUITES: Array[Script] = [
	preload("res://tests/phase0_tests.gd"),
	preload("res://tests/core_tests.gd"),
	preload("res://tests/balance_tests.gd"),
]


func _init() -> void:
	var passed: int = 0
	var failed: int = 0
	for suite in SUITES:
		var names: Array = suite.call("test_names")
		for test_name in names:
			var before: int = T.failure_count()
			var label: String = suite.call(test_name)
			if T.failure_count() == before:
				passed += 1
				print("[PASS] " + label)
			else:
				failed += 1
				print("[FAIL] " + label)
				for i in range(before, T.failure_count()):
					print("       - " + T.failures[i])

	print("")
	print("Tests: %d passed, %d failed (%d checks)" % [passed, failed, T.checks])
	quit(1 if failed > 0 else 0)
