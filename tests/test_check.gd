extends RefCounted
## Minimal check helper for headless tests.
## GDScript assert() does not stop a --script run or change the exit code,
## so every test records failures here and run_tests.gd exits 1 if any exist.

static var failures: Array[String] = []
static var checks: int = 0


static func ok(cond: bool, msg: String) -> bool:
	checks += 1
	if not cond:
		failures.append(msg)
		push_error("[CHECK FAILED] " + msg)
	return cond


static func near(actual: float, expected: float, msg: String, eps: float = 0.01) -> bool:
	return ok(absf(actual - expected) < eps, "%s (expected %s, got %s)" % [msg, expected, actual])


static func eq(actual: Variant, expected: Variant, msg: String) -> bool:
	return ok(actual == expected, "%s (expected %s, got %s)" % [msg, expected, actual])


static func failure_count() -> int:
	return failures.size()
