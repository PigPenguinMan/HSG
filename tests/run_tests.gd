extends SceneTree


func _init() -> void:
	var results := Phase0Tests.run_all()
	for line in results:
		print(line)
	print("All Phase 0 tests passed (%d/%d)." % [results.size(), results.size()])
	quit(0)
