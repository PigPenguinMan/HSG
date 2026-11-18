extends RefCounted
## src/core/ tests: passive tree data integrity, affix rolling rules, StatAggregator.clone().

const T := preload("res://tests/test_check.gd")

const TREE_PATH: String = "res://data/passive_tree.json"
const AFFIX_PATH: String = "res://data/affixes.json"
const SLOTS: Array[String] = ["WEAPON", "ARMOUR", "BOOTS", "RING", "AMULET"]
const SEEDS_PER_CASE: int = 200


static func test_names() -> Array[String]:
	return [
		"_test_tree_data_integrity",
		"_test_tree_allocate_all_and_refund_all",
		"_test_affix_data_integrity",
		"_test_rare_and_magic_roll_rules",
		"_test_fire_and_spell_affixes_rollable",
		"_test_zenith_adds_one_mod_up_to_six",
		"_test_stat_aggregator_clone",
	]


# ---------------------------------------------------------------- passive tree

static func _test_tree_data_integrity() -> String:
	var tree := PassiveTreeGraph.new()
	T.ok(tree.load_from_json_file(TREE_PATH), "load passive_tree.json")
	T.eq(tree.nodes.size(), 51, "node count")

	var type_counts: Dictionary = {}
	for nid in tree.nodes.keys():
		var node: Dictionary = tree.nodes[nid]
		var t: String = str(node.get("type", ""))
		type_counts[t] = int(type_counts.get(t, 0)) + 1
		var adj: Array = node.get("adjacentIds", [])
		T.ok(not adj.is_empty(), "%s has no neighbours" % nid)
		for other in adj:
			var oid: String = str(other)
			T.ok(oid != nid, "%s links to itself" % nid)
			if not T.ok(tree.nodes.has(oid), "%s -> missing node %s" % [nid, oid]):
				continue
			var back: Array = tree.nodes[oid].get("adjacentIds", [])
			T.ok(back.has(nid), "edge %s -> %s is not bidirectional" % [nid, oid])

	T.eq(int(type_counts.get("START", 0)), 1, "exactly one START node")
	T.eq(int(type_counts.get("APEX", 0)), 3, "v0.1 has 3 apex nodes")
	T.ok(tree.start_node_id != "", "start node resolved")

	var reachable := _reachable_from_start(tree)
	T.eq(reachable.size(), tree.nodes.size(), "every node reachable from start")
	return "PassiveTree data: 51 nodes, 1 START, 3 APEX, edges bidirectional, all reachable"


static func _test_tree_allocate_all_and_refund_all() -> String:
	var tree := PassiveTreeGraph.new()
	tree.load_from_json_file(TREE_PATH)

	# Allocate in BFS order: every node must be allocatable once a neighbour is taken.
	var order := _reachable_from_start(tree)
	for nid in order:
		if nid == tree.start_node_id:
			continue
		T.ok(tree.allocate(nid), "allocate %s in BFS order" % nid)
	T.eq(tree.allocated.size(), tree.nodes.size(), "all nodes allocated")
	T.ok(not tree.allocate(order[1]), "re-allocating a node is rejected")
	T.ok(not tree.can_refund(tree.start_node_id), "START can never be refunded")

	var agg := StatAggregator.new()
	tree.collect_modifiers(agg)
	T.ok(agg._modifiers.size() > 0, "full tree yields modifiers")

	# Refund in reverse BFS order: leaves first, so each refund keeps the tree connected.
	for i in range(order.size() - 1, 0, -1):
		T.ok(tree.refund(order[i]), "refund %s in reverse BFS order" % order[i])
	T.eq(tree.allocated.size(), 1, "only START remains after full refund")
	return "PassiveTree: allocate all 50 nodes in BFS order, refund all in reverse"


static func _reachable_from_start(tree: PassiveTreeGraph) -> Array[String]:
	var order: Array[String] = [tree.start_node_id]
	var seen: Dictionary = {tree.start_node_id: true}
	var head: int = 0
	while head < order.size():
		var curr: String = order[head]
		head += 1
		var adj: Array = tree.nodes[curr].get("adjacentIds", [])
		for other in adj:
			var oid: String = str(other)
			if seen.has(oid) or not tree.nodes.has(oid):
				continue
			seen[oid] = true
			order.append(oid)
	return order


# ---------------------------------------------------------------- affixes

static func _load_gen() -> ItemGenerator:
	var gen := ItemGenerator.new()
	T.ok(gen.load_affixes_from_json_file(AFFIX_PATH), "load affixes.json")
	return gen


static func _affix_by_id(gen: ItemGenerator) -> Dictionary:
	var by_id: Dictionary = {}
	for aff in gen.affix_pool:
		by_id[str(aff.get("id", ""))] = aff
	return by_id


static func _test_affix_data_integrity() -> String:
	var gen := _load_gen()
	T.eq(gen.affix_pool.size(), 27, "affix count")
	var by_id := _affix_by_id(gen)
	T.eq(by_id.size(), gen.affix_pool.size(), "affix ids are unique")
	for aff in gen.affix_pool:
		var aid: String = str(aff.get("id", ""))
		var kind: String = str(aff.get("kind", ""))
		T.ok(kind == "PREFIX" or kind == "SUFFIX", "%s kind is PREFIX/SUFFIX" % aid)
		T.ok(str(aff.get("group", "")) != "", "%s has a group" % aid)
		T.ok(str(aff.get("stat", "")) != "", "%s has a stat" % aid)
		T.ok(int(aff.get("minValue", 0)) <= int(aff.get("maxValue", 0)), "%s minValue <= maxValue" % aid)
		T.ok(int(aff.get("weight", 0)) > 0, "%s weight > 0" % aid)
		var slots: Array = aff.get("slots", [])
		for s in slots:
			T.ok(SLOTS.has(str(s)), "%s has unknown slot %s" % [aid, s])
	return "Affix data: 27 unique affixes, valid kind/group/value range/weight/slots"


## Checks every rolled mod against the affix definition and the item rules.
static func _check_item_mods(gen: ItemGenerator, item: Dictionary, by_id: Dictionary, max_pre: int, max_suf: int, ctx: String) -> void:
	var pre: Array = item["prefixes"]
	var suf: Array = item["suffixes"]
	T.ok(pre.size() <= max_pre, "%s: prefixes %d > %d" % [ctx, pre.size(), max_pre])
	T.ok(suf.size() <= max_suf, "%s: suffixes %d > %d" % [ctx, suf.size(), max_suf])
	var groups: Dictionary = {}
	for list in [pre, suf]:
		for m in list:
			var mid: String = str(m.get("modId", ""))
			if not T.ok(by_id.has(mid), "%s: unknown mod %s" % [ctx, mid]):
				continue
			var aff: Dictionary = by_id[mid]
			var expected_kind: String = "PREFIX" if list == pre else "SUFFIX"
			T.eq(str(aff.get("kind")), expected_kind, "%s: %s placed in %s list" % [ctx, mid, expected_kind])
			var slots: Array = aff.get("slots", [])
			T.ok(slots.is_empty() or slots.has(item["slot"]), "%s: %s not allowed on %s" % [ctx, mid, item["slot"]])
			T.ok(int(aff.get("minLevel", 1)) <= int(item["itemLevel"]), "%s: %s above item level" % [ctx, mid])
			var v: int = int(m.get("value", 0))
			T.ok(v >= int(aff.get("minValue", 0)) and v <= int(aff.get("maxValue", 0)), "%s: %s value %d out of range" % [ctx, mid, v])
			var g: String = str(m.get("group", ""))
			T.ok(not groups.has(g), "%s: duplicate group %s" % [ctx, g])
			groups[g] = true


static func _test_rare_and_magic_roll_rules() -> String:
	var gen := _load_gen()
	var by_id := _affix_by_id(gen)
	var fail_before: int = T.failure_count()
	for slot in SLOTS:
		for ilvl in [1, 10, 30]:
			for s in range(SEEDS_PER_CASE):
				var rare := gen.create_normal_item("base", slot, ilvl, s)
				T.ok(gen.apply_currency(rare, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE), "forge on normal")
				var n: int = rare["prefixes"].size() + rare["suffixes"].size()
				# Pool size can cap the count below 4 on narrow slots/low ilvl; never above 6.
				# Low ilvl can shrink the pool below 4; at ilvl 30 every slot has room for >= 4.
				var min_mods: int = 4 if ilvl >= 30 else 1
				T.ok(n >= min_mods and n <= 6, "rare %s ilvl%d seed%d has %d mods" % [slot, ilvl, s, n])
				_check_item_mods(gen, rare, by_id, 3, 3, "rare %s ilvl%d seed%d" % [slot, ilvl, s])

				var magic := gen.create_normal_item("base", slot, ilvl, s)
				T.ok(gen.apply_currency(magic, StatTypes.CurrencyType.BLOODSTONE_OF_SHIFT), "shift on normal")
				var m: int = magic["prefixes"].size() + magic["suffixes"].size()
				T.ok(m >= 1 and m <= 2, "magic %s ilvl%d seed%d has %d mods" % [slot, ilvl, s, m])
				_check_item_mods(gen, magic, by_id, 1, 1, "magic %s ilvl%d seed%d" % [slot, ilvl, s])
				if T.failure_count() - fail_before > 20:
					return "Affix rolls: stopped early after 20 failures"
	return "Affix rolls: rare <=3/3 & <=6, magic 1-2 & <=1/1, slot/ilvl/range/group rules (3000 items)"


static func _test_fire_and_spell_affixes_rollable() -> String:
	var gen := _load_gen()
	var by_id := _affix_by_id(gen)
	var targets: Array[String] = ["added_fire_t2", "spell_pct_t1", "spell_pct_t2", "fire_res_t2", "fire_res_t3"]
	var seen: Dictionary = {}
	for slot in SLOTS:
		for s in range(SEEDS_PER_CASE):
			var item := gen.create_normal_item("base", slot, 30, 10000 + s)
			gen.apply_currency(item, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE)
			for list in [item["prefixes"], item["suffixes"]]:
				for m in list:
					seen[str(m.get("modId", ""))] = true
	for aid in targets:
		if T.ok(by_id.has(aid), "affix %s exists" % aid):
			T.ok(seen.has(aid), "affix %s never rolled in 1000 rare items at ilvl 30" % aid)
	return "Fire/spell affixes: all 5 roll on allowed slots at ilvl 30"


static func _test_zenith_adds_one_mod_up_to_six() -> String:
	var gen := _load_gen()
	var by_id := _affix_by_id(gen)
	# WEAPON has 4 prefix + 6 suffix groups, so 6 mods are reachable (RING/ARMOUR cap at 5).
	var item := gen.create_normal_item("base", "WEAPON", 30, 4242)
	gen.apply_currency(item, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE)
	var guard: int = 0
	while item["prefixes"].size() + item["suffixes"].size() < 6 and guard < 6:
		var before: int = item["prefixes"].size() + item["suffixes"].size()
		if not T.ok(gen.apply_currency(item, StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH), "zenith on rare with %d mods" % before):
			break
		T.eq(item["prefixes"].size() + item["suffixes"].size(), before + 1, "zenith adds exactly one mod")
		guard += 1
	T.ok(not gen.apply_currency(item, StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH), "zenith rejected at 6 mods")
	_check_item_mods(gen, item, by_id, 3, 3, "zenith weapon")

	var normal := gen.create_normal_item("base", "RING", 30, 1)
	T.ok(not gen.apply_currency(normal, StatTypes.CurrencyType.BLOODSTONE_OF_ZENITH), "zenith rejected on normal")
	T.ok(not gen.apply_currency(normal, StatTypes.CurrencyType.BLOODSTONE_OF_RUIN), "ruin rejected on normal")
	T.ok(not gen.apply_currency(normal, StatTypes.CurrencyType.BLOODSTONE_OF_PURGE), "purge rejected on normal")
	return "Zenith: +1 mod per use up to 6, rejected at 6; invalid currencies rejected on normal"


# ---------------------------------------------------------------- StatAggregator.clone()

static func _test_stat_aggregator_clone() -> String:
	var agg := StatAggregator.new()
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.FLAT, 10.0))
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.INCREASED, 50.0))
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.MORE, 20.0, "rune_savagery"))
	agg.add_modifier(StatTypes.make_mod("BLOODTHIRST", StatTypes.ModType.FLAG, 1.0))
	agg.add_modifier(StatTypes.make_mod("FIRE_DAMAGE", StatTypes.ModType.INCREASED, 30.0, "", ["SPELL"]))

	var copy := agg.clone()
	# (100 + 10) * 1.5 * 1.2 = 198
	T.near(copy.get_stat("PHYSICAL_DAMAGE", 100.0), agg.get_stat("PHYSICAL_DAMAGE", 100.0), "clone keeps stat value")
	T.near(copy.get_stat("PHYSICAL_DAMAGE", 100.0), 198.0, "clone stat value")
	T.ok(copy.has_flag("BLOODTHIRST"), "clone keeps flags")
	T.near(copy.get_stat("FIRE_DAMAGE", 100.0, ["SPELL"]), 130.0, "clone keeps tag-scoped mods")
	T.near(copy.get_stat("FIRE_DAMAGE", 100.0, ["ATTACK"]), 100.0, "tag-scoped mod ignored without tag")

	# Same-source MORE stays deduplicated in the clone.
	copy.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.MORE, 20.0, "rune_savagery"))
	T.near(copy.get_stat("PHYSICAL_DAMAGE", 100.0), 198.0, "clone keeps More dedup")

	# Mutating the clone must not leak into the original.
	copy.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.INCREASED, 50.0))
	copy.clear()
	T.near(agg.get_stat("PHYSICAL_DAMAGE", 100.0), 198.0, "original unaffected by clone add/clear")
	T.ok(agg.has_flag("BLOODTHIRST"), "original keeps flag after clone clear")
	return "StatAggregator.clone(): values, flags, tags, More dedup preserved; independent of original"
