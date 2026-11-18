extends RefCounted
## SaveCodec / SaveManager / Player save tests (HANDOFF §13).
## Never touches the real save (user://save_slot_1.json): file tests use TEST_PATH.

const T := preload("res://tests/test_check.gd")
const SaveCodecScript := preload("res://src/core/save_codec.gd")
const SaveManagerScript := preload("res://src/world/save_manager.gd")
const BalanceDBScript := preload("res://src/core/balance_db.gd")

const TEST_PATH: String = "user://__test_save_slot.json"


static func test_names() -> Array[String]:
	return [
		"_test_codec_round_trip",
		"_test_loaded_item_crafts_like_original",
		"_test_codec_rejects_bad_input",
		"_test_manager_file_round_trip_and_corruption",
		"_test_player_save_dict_round_trip",
		"_test_player_drops_unknown_passive_nodes",
		"_test_mana_flask_rules",
	]


static func _gen() -> ItemGenerator:
	var gen := ItemGenerator.new()
	gen.load_affixes_from_json_file("res://data/affixes.json")
	return gen


static func _sample_state() -> Dictionary:
	var gen := _gen()
	var weapon := gen.create_normal_item("base_wolf_weapon", "WEAPON", 12, 7777)
	gen.apply_currency(weapon, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE)
	gen.apply_currency(weapon, StatTypes.CurrencyType.BLOODSTONE_OF_RUIN)
	var ring := gen.create_normal_item("base_wolf_ring", "RING", 8, 4242)
	gen.apply_currency(ring, StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT)
	var boots := gen.create_normal_item("base_wolf_boots", "BOOTS", 3, 31)
	return {
		"save_version": SaveCodecScript.SAVE_VERSION,
		"player": {
			"level": 7, "xp": 123, "xp_to_next": 412, "passive_points": 3,
			"allocated_nodes": ["node_wolf_start", "node_life_01", "node_ms_01"],
			"equipment": {"WEAPON": weapon, "ARMOUR": null, "BOOTS": null, "RING_1": ring, "RING_2": null, "AMULET": null},
			"inventory": [boots],
			"currency_pouch": {
				StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT: 4,
				StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH: 1,
			},
			"skill_slots": {"LMB": {"skill_id": "crimson_flurry", "runes": ["rune_savagery"]}, "Q": {"skill_id": "bloodmoon_orb", "runes": []}},
			"life_flask_charges": 2, "mana_flask_charges": 5,
		},
		"world": {
			"respawn_zone": "field_1", "respawn_pos": Vector2(1234.5, 678.0),
			"discovered_waypoints": ["town", "field_1"],
			"boss_defeated": true, "hor_reward_claimed": false,
			"loot_seed": 1042, "kills": 88,
		},
	}


## Same as ==, but also requires identical Variant types (3 vs 3.0 must fail).
static func _strict_equal(a: Variant, b: Variant, path: String) -> bool:
	if typeof(a) != typeof(b):
		return T.ok(false, "%s: type %s != %s (%s vs %s)" % [path, type_string(typeof(a)), type_string(typeof(b)), a, b])
	if a is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		var good: bool = T.ok(da.size() == db.size(), "%s: key count %d != %d (%s vs %s)" % [path, da.size(), db.size(), da.keys(), db.keys()])
		for k in da.keys():
			if not T.ok(db.has(k), "%s: missing key %s (%s)" % [path, k, type_string(typeof(k))]):
				good = false
				continue
			good = _strict_equal(da[k], db[k], "%s.%s" % [path, k]) and good
		return good
	if a is Array:
		var aa: Array = a
		var ab: Array = b
		if not T.ok(aa.size() == ab.size(), "%s: length %d != %d" % [path, aa.size(), ab.size()]):
			return false
		var good_a: bool = true
		for i in range(aa.size()):
			good_a = _strict_equal(aa[i], ab[i], "%s[%d]" % [path, i]) and good_a
		return good_a
	return T.ok(a == b, "%s: %s != %s" % [path, a, b])


## Items rolled from JSON affix data carry float tiers; the codec stores ints.
## Normalise the expected side so the strict comparison checks the contract, not data-file quirks.
static func _normalise_items(state: Dictionary) -> Dictionary:
	var s: Dictionary = state.duplicate(true)
	var p: Dictionary = s["player"]
	var items: Array = []
	for k in p["equipment"].keys():
		if p["equipment"][k] is Dictionary:
			items.append(p["equipment"][k])
	items.append_array(p["inventory"])
	for it in items:
		for list in [it["prefixes"], it["suffixes"]]:
			for m in list:
				m["tier"] = int(m["tier"])
	return s


static func _test_codec_round_trip() -> String:
	var state := _sample_state()
	var res: Dictionary = SaveCodecScript.decode(SaveCodecScript.encode(state))
	if not T.ok(bool(res.get("ok", false)), "decode ok (error: %s)" % res.get("error", "")):
		return "SaveCodec round trip"
	var back: Dictionary = res["state"]
	_strict_equal(back, _normalise_items(state), "state")

	var pouch: Dictionary = back["player"]["currency_pouch"]
	T.ok(pouch.has(StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT), "pouch has int key SHIFT")
	T.eq(typeof(back["player"]["equipment"]["WEAPON"]["seed"]), TYPE_INT, "item seed is int")
	T.ok(back["world"]["respawn_pos"] is Vector2, "respawn_pos is Vector2")
	return "SaveCodec: encode->decode keeps every value and type (int seeds, int pouch keys, Vector2)"


static func _test_loaded_item_crafts_like_original() -> String:
	var gen := _gen()
	var state := _sample_state()
	var back: Dictionary = SaveCodecScript.decode(SaveCodecScript.encode(state))["state"]
	for slot in ["WEAPON", "RING_1"]:
		var orig: Dictionary = (state["player"]["equipment"][slot] as Dictionary).duplicate(true)
		var loaded: Dictionary = (back["player"]["equipment"][slot] as Dictionary).duplicate(true)
		var cur: int = StatTypes.CurrencyType.BLOODSTONE_OF_RUIN if slot == "WEAPON" else StatTypes.CurrencyType.BLOODSTONE_OF_PURGE
		T.ok(gen.apply_currency(orig, cur), "%s currency on original" % slot)
		T.ok(gen.apply_currency(loaded, cur), "%s currency on loaded" % slot)
		var same: bool = str(orig["prefixes"]) == str(loaded["prefixes"]) and str(orig["suffixes"]) == str(loaded["suffixes"]) and orig["rollCount"] == loaded["rollCount"]
		T.ok(same, "%s: crafting after load differs from before save\n  before: %s %s\n  after:  %s %s" % [slot, orig["prefixes"], orig["suffixes"], loaded["prefixes"], loaded["suffixes"]])
	# Several more Ruins in a row on the weapon, to cover the whole seed sequence.
	var a: Dictionary = (state["player"]["equipment"]["WEAPON"] as Dictionary).duplicate(true)
	var b: Dictionary = (back["player"]["equipment"]["WEAPON"] as Dictionary).duplicate(true)
	for i in range(5):
		gen.apply_currency(a, StatTypes.CurrencyType.BLOODSTONE_OF_RUIN)
		gen.apply_currency(b, StatTypes.CurrencyType.BLOODSTONE_OF_RUIN)
	T.ok(str(a["prefixes"]) + str(a["suffixes"]) == str(b["prefixes"]) + str(b["suffixes"]), "5 more Ruins match after load")
	return "Save-scum: crafting a loaded item gives the same result as before saving"


static func _test_codec_rejects_bad_input() -> String:
	var good: Dictionary = JSON.parse_string(SaveCodecScript.encode(_sample_state()))
	var cases: Dictionary = {
		"empty": "",
		"garbage": "{not json",
		"array root": "[1,2,3]",
	}
	var no_version: Dictionary = good.duplicate(true)
	no_version.erase("save_version")
	cases["no save_version"] = JSON.stringify(no_version)
	var future: Dictionary = good.duplicate(true)
	future["save_version"] = SaveCodecScript.SAVE_VERSION + 1
	cases["future version"] = JSON.stringify(future)
	var no_world: Dictionary = good.duplicate(true)
	no_world.erase("world")
	cases["no world"] = JSON.stringify(no_world)
	var no_level: Dictionary = good.duplicate(true)
	no_level["player"].erase("level")
	cases["no player.level"] = JSON.stringify(no_level)
	var bad_pos: Dictionary = good.duplicate(true)
	bad_pos["world"]["respawn_pos"] = "here"
	cases["bad respawn_pos"] = JSON.stringify(bad_pos)
	var bad_inv: Dictionary = good.duplicate(true)
	bad_inv["player"]["inventory"] = {"a": 1}
	cases["inventory not array"] = JSON.stringify(bad_inv)

	for label in cases.keys():
		var res: Dictionary = SaveCodecScript.decode(cases[label])
		T.ok(not bool(res.get("ok", true)), "decode should reject: %s" % label)
		T.ok(str(res.get("error", "")) != "", "rejection has an error message: %s" % label)
	return "SaveCodec: rejects empty, garbage, wrong/missing version, missing sections/keys, bad types"


static func _test_manager_file_round_trip_and_corruption() -> String:
	_cleanup()
	var state := _sample_state()
	T.ok(SaveManagerScript.save_state(state, TEST_PATH), "save_state returns true")
	T.ok(FileAccess.file_exists(TEST_PATH), "save file written")
	T.ok(not FileAccess.file_exists(TEST_PATH + ".tmp"), ".tmp removed after save")

	var loaded: Dictionary = SaveManagerScript.load_state(TEST_PATH)
	T.ok(bool(loaded.get("exists", false)) and not bool(loaded.get("corrupted", true)), "load_state finds a valid save")
	_strict_equal(loaded.get("state", {}), _normalise_items(state), "file state")

	# Overwrite an existing save (rename onto an existing file).
	state["player"]["level"] = 8
	T.ok(SaveManagerScript.save_state(state, TEST_PATH), "second save over existing file")
	T.eq(int(SaveManagerScript.load_state(TEST_PATH)["state"]["player"]["level"]), 8, "second save replaced the first")

	# Corrupt the file: loader must back it up and report corruption.
	var f := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	f.store_string("{\"save_version\": 1, \"player\": ")
	f.close()
	var bad: Dictionary = SaveManagerScript.load_state(TEST_PATH)
	T.ok(bool(bad.get("corrupted", false)), "truncated file reported as corrupted")
	T.ok(FileAccess.file_exists(TEST_PATH + ".bak"), "corrupted file moved to .bak")
	T.ok(not FileAccess.file_exists(TEST_PATH), "corrupted file no longer at save path")

	var none: Dictionary = SaveManagerScript.load_state(TEST_PATH)
	T.ok(not bool(none.get("exists", true)), "after backup, no save exists -> new game")
	_cleanup()
	return "SaveManager: atomic save, overwrite, load, corrupted file -> .bak + new game"


static func _cleanup() -> void:
	for p in [TEST_PATH, TEST_PATH + ".tmp", TEST_PATH + ".bak"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


# ---------------------------------------------------------------- Player (needs the scene tree for _ready)

static func _spawn_player() -> Player:
	var tree := Engine.get_main_loop() as SceneTree
	var p := Player.new()
	tree.root.add_child(p)
	T.ok(p.is_node_ready() and not p.passive_tree.nodes.is_empty(), "Player._ready ran (tree loaded) before the test uses it")
	return p


static func _test_player_save_dict_round_trip() -> String:
	var p := _spawn_player()
	var gen := _gen()
	p.level = 5
	p.xp = 40
	p.passive_points = 1
	p.passive_tree.allocate("node_life_01")
	var w := gen.create_normal_item("base_wolf_weapon", "WEAPON", 10, 99)
	gen.apply_currency(w, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE)
	p.equipment["WEAPON"] = w
	p.currency_pouch[StatTypes.CurrencyType.BLOODSTONE_OF_RUIN] = 9
	p.life_flask_charges = 1
	p.mana_flask_charges = 4
	p.recalculate_stats()
	var hp_before: float = p.max_hp

	var text: String = SaveCodecScript.encode({"save_version": 1, "player": p.to_save_dict(), "world": _sample_state()["world"]})
	var res: Dictionary = SaveCodecScript.decode(text)
	T.ok(bool(res["ok"]), "player state decodes")

	var q := _spawn_player()
	q.apply_save_dict(res["state"]["player"])
	T.eq(q.level, 5, "level restored")
	T.eq(q.xp, 40, "xp restored")
	T.eq(q.passive_points, 1, "passive points restored")
	T.ok(q.passive_tree.allocated.has("node_life_01"), "allocated node restored")
	T.ok(q.passive_tree.allocated.has(q.passive_tree.start_node_id), "start node kept")
	T.eq(int(q.currency_pouch.get(StatTypes.CurrencyType.BLOODSTONE_OF_RUIN, 0)), 9, "currency restored under int key")
	T.eq(q.life_flask_charges, 1, "life flask charges restored")
	T.eq(q.mana_flask_charges, 4, "mana flask charges restored")
	T.ok(q.equipment["WEAPON"] is Dictionary and int(q.equipment["WEAPON"]["seed"]) == 99, "weapon restored")
	T.near(q.max_hp, hp_before, "stats recalculated from restored gear/tree")
	T.near(q.hp, q.max_hp, "hp full after load")
	p.free()
	q.free()
	return "Player: to_save_dict -> codec -> apply_save_dict restores progress, gear, pouch, flasks, stats"


static func _test_player_drops_unknown_passive_nodes() -> String:
	var p := _spawn_player()
	var d: Dictionary = p.to_save_dict()
	d["passive_points"] = 0
	d["allocated_nodes"] = ["node_wolf_start", "node_life_01", "node_removed_in_patch", "node_also_gone"]
	p.apply_save_dict(d)
	T.ok(p.passive_tree.allocated.has("node_life_01"), "known node kept")
	T.ok(not p.passive_tree.allocated.has("node_removed_in_patch"), "unknown node dropped")
	T.eq(p.passive_points, 2, "2 unknown nodes refunded as 2 points")
	p.free()
	return "Player: unknown passive nodes in a save are dropped and refunded"


# ---------------------------------------------------------------- mana flask (HANDOFF §13.3)

static func _press(key: Key, down: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	ev.pressed = down
	Input.parse_input_event(ev)
	Input.flush_buffered_events()


static func _tap(p: Player, key: Key) -> void:
	_press(key, true)
	p._physics_process(0.016)
	_press(key, false)
	p._physics_process(0.016)


static func _test_mana_flask_rules() -> String:
	var bal: Dictionary = BalanceDBScript.get_section("player")
	var restore: float = float(bal.get("mana_flask_restore", 0.0))
	var p := _spawn_player()
	p.set_physics_process(false)
	p.recalculate_stats()

	p.mana = 0.0
	p.mana_flask_charges = 2
	p.life_flask_charges = 3
	_tap(p, KEY_2)
	T.eq(p.mana_flask_charges, 1, "mana flask consumes one charge")
	T.ok(p.mana >= restore - 1.0 or p.mana == p.max_mana, "mana restored by ~%s (got %s)" % [restore, p.mana])
	T.eq(p.life_flask_charges, 3, "life flask untouched by key 2")

	# Holding the key must not drain every frame.
	p.mana = 0.0
	p.mana_flask_charges = 3
	_press(KEY_2, true)
	for i in range(10):
		p._physics_process(0.016)
	_press(KEY_2, false)
	p._physics_process(0.016)
	T.eq(p.mana_flask_charges, 2, "holding key 2 uses only one charge")

	p.mana = p.max_mana
	_tap(p, KEY_2)
	T.eq(p.mana_flask_charges, 2, "full mana: no charge spent")

	p.mana_flask_charges = 0
	p.mana = 0.0
	_tap(p, KEY_2)
	T.near(p.mana, 0.0 + 8.0 * 0.032, "no charges: mana only regenerates", 0.5)

	# Bloodthirst: max mana 0, flask unusable and charges kept.
	p.stats.add_modifier(StatTypes.make_mod("BLOODTHIRST", StatTypes.ModType.FLAG, 1.0))
	p.max_mana = 0.0
	p.mana = 0.0
	p.mana_flask_charges = 3
	_tap(p, KEY_2)
	T.eq(p.mana_flask_charges, 3, "bloodthirst: no charge spent")

	# Kills charge both flasks up to their caps.
	p.life_flask_charges = 0
	p.mana_flask_charges = 0
	p.on_enemy_killed(true, 0)
	T.eq(p.life_flask_charges, 2, "rare kill +2 life charges")
	T.eq(p.mana_flask_charges, 2, "rare kill +2 mana charges")
	for i in range(10):
		p.on_enemy_killed(false, 0)
	T.eq(p.mana_flask_charges, int(bal.get("mana_flask_max_charges", 0)), "mana charges capped")
	p.free()
	return "Mana flask: key 2, 1 charge per press, not on full mana/no charges/bloodthirst, kill recharge capped"
