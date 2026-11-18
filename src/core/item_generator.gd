class_name ItemGenerator
extends RefCounted

var affix_pool: Array = []


func load_affixes_from_dict(data: Dictionary) -> void:
	affix_pool = data.get("affixes", [])


func load_affixes_from_json_file(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		load_affixes_from_dict(parsed)
		return true
	return false


func create_normal_item(base_id: String, slot: String, item_level: int, seed_val: int) -> Dictionary:
	return {
		"uid": "item_%d" % seed_val,
		"baseId": base_id,
		"slot": slot,
		"rarity": StatTypes.Rarity.NORMAL,
		"itemLevel": item_level,
		"seed": seed_val,
		"rollCount": 0,
		"prefixes": [],
		"suffixes": [],
	}


func apply_currency(item: Dictionary, currency: int) -> bool:
	var rarity: int = int(item.get("rarity", StatTypes.Rarity.NORMAL))
	var rng := RandomNumberGenerator.new()
	var roll_count: int = int(item.get("rollCount", 0)) + 1
	item["rollCount"] = roll_count
	rng.seed = hash(str(item.get("seed", 0)) + ":" + str(roll_count))

	match currency:
		StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT:
			if rarity != StatTypes.Rarity.NORMAL:
				return false
			item["rarity"] = StatTypes.Rarity.MAGIC
			_roll_mods(item, rng, 1, 2, 1, 1)
			return true

		StatTypes.CurrencyType.BLOODSTONE_OF_FORGE:
			if rarity != StatTypes.Rarity.NORMAL:
				return false
			item["rarity"] = StatTypes.Rarity.RARE
			_roll_mods(item, rng, 4, 6, 3, 3)
			return true

		StatTypes.CurrencyType.BLOODSTONE_OF_RUIN:
			if rarity != StatTypes.Rarity.RARE:
				return false
			_roll_mods(item, rng, 4, 6, 3, 3)
			return true

		StatTypes.CurrencyType.BLOODSTONE_OF_PURGE:
			if rarity == StatTypes.Rarity.NORMAL:
				return false
			item["rarity"] = StatTypes.Rarity.NORMAL
			item["prefixes"] = []
			item["suffixes"] = []
			return true

		StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH:
			if rarity != StatTypes.Rarity.RARE:
				return false
			var total_mods: int = item["prefixes"].size() + item["suffixes"].size()
			if total_mods >= 6:
				return false
			return _add_single_mod(item, rng, 3, 3)

	return false


func _roll_mods(item: Dictionary, rng: RandomNumberGenerator, min_count: int, max_count: int, max_pre: int, max_suf: int) -> void:
	item["prefixes"] = []
	item["suffixes"] = []
	var target: int = rng.randi_range(min_count, max_count)
	for _i in range(target):
		if not _add_single_mod(item, rng, max_pre, max_suf):
			break


func _add_single_mod(item: Dictionary, rng: RandomNumberGenerator, max_pre: int, max_suf: int) -> bool:
	var can_pre: bool = item["prefixes"].size() < max_pre
	var can_suf: bool = item["suffixes"].size() < max_suf
	if not can_pre and not can_suf:
		return false

	var used_groups: Dictionary = {}
	for p in item["prefixes"]:
		used_groups[p["group"]] = true
	for s in item["suffixes"]:
		used_groups[s["group"]] = true

	var slot: String = str(item.get("slot", ""))
	var ilvl: int = int(item.get("itemLevel", 1))
	var candidates: Array = []
	var total_weight: int = 0

	for aff in affix_pool:
		var kind: String = str(aff.get("kind", "PREFIX"))
		if kind == "PREFIX" and not can_pre:
			continue
		if kind == "SUFFIX" and not can_suf:
			continue
		if int(aff.get("minLevel", 1)) > ilvl:
			continue
		if used_groups.has(str(aff.get("group", ""))):
			continue
		var slots: Array = aff.get("slots", [])
		if not slots.is_empty() and not slots.has(slot):
			continue
		var w: int = int(aff.get("weight", 100))
		if w <= 0:
			continue
		candidates.append(aff)
		total_weight += w

	if candidates.is_empty() or total_weight <= 0:
		return false

	var roll: int = rng.randi_range(1, total_weight)
	var acc: int = 0
	var chosen: Dictionary = candidates[0]
	for c in candidates:
		acc += int(c.get("weight", 100))
		if roll <= acc:
			chosen = c
			break

	var val: int = rng.randi_range(int(chosen.get("minValue", 1)), int(chosen.get("maxValue", 1)))
	var mod_instance := {
		"modId": chosen.get("id"),
		"group": chosen.get("group"),
		"tier": chosen.get("tier"),
		"stat": chosen.get("stat"),
		"modType": chosen.get("modType"),
		"value": val,
	}

	if str(chosen.get("kind", "PREFIX")) == "PREFIX":
		item["prefixes"].append(mod_instance)
	else:
		item["suffixes"].append(mod_instance)
	return true
