class_name StatAggregator
extends RefCounted

var _modifiers: Array[Dictionary] = []
var _seen_more_sources: Dictionary = {}


func clear() -> void:
	_modifiers.clear()
	_seen_more_sources.clear()


func add_modifier(mod: Dictionary) -> void:
	if mod.get("mod_type") == StatTypes.ModType.MORE:
		var source_id: String = str(mod.get("source_id", ""))
		if source_id != "":
			var key := "%s::%s" % [str(mod.get("stat", "")), source_id]
			if _seen_more_sources.has(key):
				return
			_seen_more_sources[key] = true
	_modifiers.append(mod)


func add_modifiers(mods: Array) -> void:
	for mod in mods:
		if mod is Dictionary:
			add_modifier(mod)


func clone() -> StatAggregator:
	var copy := StatAggregator.new()
	copy.add_modifiers(_modifiers)
	return copy


func has_flag(stat_name: String) -> bool:
	for mod in _modifiers:
		if mod.get("stat") == stat_name and mod.get("mod_type") == StatTypes.ModType.FLAG and float(mod.get("value", 0.0)) > 0.0:
			return true
	return false


func get_stat(stat_name: String, base_value: float = 0.0, context_tags: Array = []) -> float:
	var flat_sum: float = base_value
	var increased_sum: float = 0.0
	var more_mult: float = 1.0

	for mod in _modifiers:
		if mod.get("stat") != stat_name:
			continue
		if not _matches_tags(mod.get("tags", []), context_tags):
			continue

		var mtype: int = int(mod.get("mod_type", StatTypes.ModType.FLAT))
		var val: float = float(mod.get("value", 0.0))
		match mtype:
			StatTypes.ModType.FLAT:
				flat_sum += val
			StatTypes.ModType.INCREASED:
				increased_sum += val / 100.0
			StatTypes.ModType.MORE:
				more_mult *= maxf(0.0, 1.0 + val / 100.0)

	var inc_mult: float = maxf(0.0, 1.0 + increased_sum)
	return flat_sum * inc_mult * more_mult


func compute_attributes(base_str: float, base_dex: float, base_int: float) -> Dictionary:
	var total_str: float = get_stat("STR", base_str)
	var total_dex: float = get_stat("DEX", base_dex)
	var total_int: float = get_stat("INT", base_int)

	return {
		"STR": total_str,
		"DEX": total_dex,
		"INT": total_int,
		"LIFE_FROM_STR": floorf(total_str / 10.0) * 5.0,
		"MELEE_PHYS_INC_FROM_STR": floorf(total_str / 10.0) * 2.0,
		"ACCURACY_FROM_DEX": total_dex * 2.0,
		"EVASION_INC_FROM_DEX": floorf(total_dex / 10.0) * 2.0,
		"MANA_FROM_INT": floorf(total_int / 10.0) * 5.0,
	}


func _matches_tags(mod_tags: Array, context_tags: Array) -> bool:
	if mod_tags.is_empty():
		return true
	for t in mod_tags:
		if context_tags.has(t):
			return true
	return false
