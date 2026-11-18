class_name SaveManager
extends RefCounted

const SaveCodecScript := preload("res://src/core/save_codec.gd")
const SAVE_PATH: String = "user://save_slot_1.json"


static func save_state(state: Dictionary, path: String = SAVE_PATH) -> bool:
	var encoded: String = SaveCodecScript.encode(state)
	var tmp_path: String = path + ".tmp"
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(encoded)
	f.flush()
	f.close()

	var abs_tmp: String = ProjectSettings.globalize_path(tmp_path)
	var abs_dst: String = ProjectSettings.globalize_path(path)
	var err: int = DirAccess.rename_absolute(abs_tmp, abs_dst)
	return err == OK


static func load_state(path: String = SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"exists": false, "corrupted": false, "error": "", "state": {}}

	var text: String = FileAccess.get_file_as_string(path)
	var res: Dictionary = SaveCodecScript.decode(text)
	if not bool(res.get("ok", false)):
		var bak_path: String = path + ".bak"
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(bak_path))
		return {
			"exists": true,
			"corrupted": true,
			"error": str(res.get("error", "corrupted")),
			"state": {},
		}

	return {
		"exists": true,
		"corrupted": false,
		"error": "",
		"state": res["state"],
	}
