class_name SaveCodec
extends RefCounted

const SAVE_VERSION: int = 1


static func encode(state: Dictionary) -> String:
	var p_in: Dictionary = state.get("player", {})
	var w_in: Dictionary = state.get("world", {})

	var pouch_out: Dictionary = {}
	var pouch_in: Dictionary = p_in.get("currency_pouch", {})
	for k in pouch_in.keys():
		pouch_out[str(k)] = int(pouch_in[k])

	var rp_raw: Variant = w_in.get("respawn_pos", [640.0, 620.0])
	var rp_arr: Array = [640.0, 620.0]
	if rp_raw is Vector2:
		var v: Vector2 = rp_raw
		rp_arr = [v.x, v.y]
	elif rp_raw is Array and rp_raw.size() >= 2:
		rp_arr = [float(rp_raw[0]), float(rp_raw[1])]

	var out: Dictionary = {
		"save_version": SAVE_VERSION,
		"player": {
			"level": int(p_in.get("level", 1)),
			"xp": int(p_in.get("xp", 0)),
			"xp_to_next": int(p_in.get("xp_to_next", 100)),
			"passive_points": int(p_in.get("passive_points", 2)),
			"allocated_nodes": p_in.get("allocated_nodes", []).duplicate(),
			"equipment": _dup_equipment(p_in.get("equipment", {})),
			"inventory": _dup_items(p_in.get("inventory", [])),
			"currency_pouch": pouch_out,
			"skill_slots": _dup_skill_slots(p_in.get("skill_slots", {})),
			"life_flask_charges": int(p_in.get("life_flask_charges", 3)),
			"mana_flask_charges": int(p_in.get("mana_flask_charges", 3)),
		},
		"world": {
			"respawn_zone": str(w_in.get("respawn_zone", "town")),
			"respawn_pos": rp_arr,
			"discovered_waypoints": w_in.get("discovered_waypoints", []).duplicate(),
			"boss_defeated": bool(w_in.get("boss_defeated", false)),
			"hor_reward_claimed": bool(w_in.get("hor_reward_claimed", false)),
			"loot_seed": int(w_in.get("loot_seed", 1000)),
			"kills": int(w_in.get("kills", 0)),
		},
	}
	return JSON.stringify(out)


static func decode(text: String) -> Dictionary:
	if text.strip_edges() == "":
		return {"ok": false, "error": "empty save text", "state": {}}
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return {"ok": false, "error": "invalid json root", "state": {}}
	var root: Dictionary = parsed

	if not root.has("save_version") or int(root["save_version"]) != SAVE_VERSION:
		return {"ok": false, "error": "unsupported save_version", "state": {}}
	if not root.has("player") or not root["player"] is Dictionary:
		return {"ok": false, "error": "missing player section", "state": {}}
	if not root.has("world") or not root["world"] is Dictionary:
		return {"ok": false, "error": "missing world section", "state": {}}

	var p_raw: Dictionary = root["player"]
	var w_raw: Dictionary = root["world"]

	var p_req: Array[String] = [
		"level", "xp", "xp_to_next", "passive_points",
		"allocated_nodes", "equipment", "inventory",
		"currency_pouch", "skill_slots",
		"life_flask_charges", "mana_flask_charges",
	]
	for k in p_req:
		if not p_raw.has(k):
			return {"ok": false, "error": "missing player key: " + k, "state": {}}

	var w_req: Array[String] = [
		"respawn_zone", "respawn_pos", "discovered_waypoints",
		"boss_defeated", "hor_reward_claimed", "loot_seed", "kills",
	]
	for k in w_req:
		if not w_raw.has(k):
			return {"ok": false, "error": "missing world key: " + k, "state": {}}

	if not p_raw["allocated_nodes"] is Array:
		return {"ok": false, "error": "invalid allocated_nodes", "state": {}}
	if not p_raw["equipment"] is Dictionary:
		return {"ok": false, "error": "invalid equipment", "state": {}}
	if not p_raw["inventory"] is Array:
		return {"ok": false, "error": "invalid inventory", "state": {}}
	if not p_raw["currency_pouch"] is Dictionary:
		return {"ok": false, "error": "invalid currency_pouch", "state": {}}
	if not p_raw["skill_slots"] is Dictionary:
		return {"ok": false, "error": "invalid skill_slots", "state": {}}
	if not w_raw["discovered_waypoints"] is Array:
		return {"ok": false, "error": "invalid discovered_waypoints", "state": {}}

	var rp_raw: Variant = w_raw["respawn_pos"]
	if not rp_raw is Array or (rp_raw as Array).size() < 2:
		return {"ok": false, "error": "invalid respawn_pos", "state": {}}
	var rp_arr: Array = rp_raw

	var alloc_nodes: Array = []
	for nid in p_raw["allocated_nodes"]:
		alloc_nodes.append(str(nid))

	var eq_out: Dictionary = {}
	var eq_raw: Dictionary = p_raw["equipment"]
	for slot_key in eq_raw.keys():
		var item_val: Variant = eq_raw[slot_key]
		if item_val is Dictionary:
			eq_out[str(slot_key)] = _decode_item(item_val)
		else:
			eq_out[str(slot_key)] = null

	var inv_out: Array = []
	for item_val in p_raw["inventory"]:
		if item_val is Dictionary:
			inv_out.append(_decode_item(item_val))

	var pouch_out: Dictionary = {}
	var pouch_raw: Dictionary = p_raw["currency_pouch"]
	for k in pouch_raw.keys():
		pouch_out[int(k)] = int(pouch_raw[k])

	var slots_out: Dictionary = _dup_skill_slots(p_raw["skill_slots"])

	var wps_out: Array = []
	for wp in w_raw["discovered_waypoints"]:
		wps_out.append(str(wp))

	var state: Dictionary = {
		"save_version": SAVE_VERSION,
		"player": {
			"level": int(p_raw["level"]),
			"xp": int(p_raw["xp"]),
			"xp_to_next": int(p_raw["xp_to_next"]),
			"passive_points": int(p_raw["passive_points"]),
			"allocated_nodes": alloc_nodes,
			"equipment": eq_out,
			"inventory": inv_out,
			"currency_pouch": pouch_out,
			"skill_slots": slots_out,
			"life_flask_charges": int(p_raw["life_flask_charges"]),
			"mana_flask_charges": int(p_raw["mana_flask_charges"]),
		},
		"world": {
			"respawn_zone": str(w_raw["respawn_zone"]),
			"respawn_pos": Vector2(float(rp_arr[0]), float(rp_arr[1])),
			"discovered_waypoints": wps_out,
			"boss_defeated": bool(w_raw["boss_defeated"]),
			"hor_reward_claimed": bool(w_raw["hor_reward_claimed"]),
			"loot_seed": int(w_raw["loot_seed"]),
			"kills": int(w_raw["kills"]),
		},
	}
	return {"ok": true, "error": "", "state": state}


static func _decode_item(raw: Dictionary) -> Dictionary:
	var item: Dictionary = {
		"uid": str(raw.get("uid", "")),
		"baseId": str(raw.get("baseId", "")),
		"slot": str(raw.get("slot", "")),
		"rarity": int(raw.get("rarity", 0)),
		"itemLevel": int(raw.get("itemLevel", 1)),
		"seed": int(raw.get("seed", 0)),
		"rollCount": int(raw.get("rollCount", 0)),
		"prefixes": _decode_mods(raw.get("prefixes", [])),
		"suffixes": _decode_mods(raw.get("suffixes", [])),
	}
	return item


static func _decode_mods(raw_mods: Variant) -> Array:
	var out: Array = []
	if not raw_mods is Array:
		return out
	for m in raw_mods:
		if not m is Dictionary:
			continue
		var md: Dictionary = m
		out.append({
			"modId": str(md.get("modId", "")),
			"group": str(md.get("group", "")),
			"tier": int(md.get("tier", 1)),
			"stat": str(md.get("stat", "")),
			"modType": str(md.get("modType", "FLAT")),
			"value": int(md.get("value", 0)),
		})
	return out


static func _dup_equipment(eq: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in eq.keys():
		var v: Variant = eq[k]
		out[str(k)] = _decode_item(v) if v is Dictionary else null
	return out


static func _dup_items(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		if v is Dictionary:
			out.append(_decode_item(v))
	return out


static func _dup_skill_slots(raw: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in raw.keys():
		var slot_v: Variant = raw[k]
		if not slot_v is Dictionary:
			continue
		var slot_d: Dictionary = slot_v
		var runes_out: Array = []
		var runes_v: Variant = slot_d.get("runes", [])
		if runes_v is Array:
			for r in runes_v:
				runes_out.append(str(r))
		out[str(k)] = {
			"skill_id": str(slot_d.get("skill_id", "")),
			"runes": runes_out,
		}
	return out
