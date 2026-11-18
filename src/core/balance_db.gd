class_name BalanceDB
extends RefCounted

const DEFAULT_PATH: String = "res://data/balance.json"

static var _loaded: bool = false
static var _data: Dictionary = {}


static func ensure_loaded(path: String = DEFAULT_PATH) -> void:
	if _loaded:
		return
	load_from(path)


static func load_from(path: String = DEFAULT_PATH) -> bool:
	_loaded = true
	if not FileAccess.file_exists(path):
		_data = {}
		return false
	var text: String = FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		_data = parsed
		return true
	_data = {}
	return false


static func get_section(key: String) -> Dictionary:
	ensure_loaded()
	var val: Variant = _data.get(key, {})
	if val is Dictionary:
		return val
	return {}
