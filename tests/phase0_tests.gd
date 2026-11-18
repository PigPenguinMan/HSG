class_name Phase0Tests
extends RefCounted

const T := preload("res://tests/test_check.gd")


## Kept for src/world/arena.gd, which prints Phase 0 results on startup.
static func run_all() -> Array[String]:
	var results: Array[String] = []
	var self_script: Script = load("res://tests/phase0_tests.gd")
	for test_name in test_names():
		var before: int = T.failure_count()
		var label: String = self_script.call(test_name)
		results.append(("[PASS] " if T.failure_count() == before else "[FAIL] ") + label)
	return results


static func test_names() -> Array[String]:
	return [
		"_test_stat_aggregator_more_dedup",
		"_test_damage_pipeline_and_no_double_dip",
		"_test_passive_tree_bfs_refund",
		"_test_item_generator_seeded_and_currency",
	]


static func _test_stat_aggregator_more_dedup() -> String:
	var agg := StatAggregator.new()
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.INCREASED, 50.0))
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.INCREASED, 50.0))
	# Same source_id MORE must not stack twice
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.MORE, 35.0, "rune_savagery"))
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.MORE, 35.0, "rune_savagery"))
	# Different source_id MORE stacks multiplicatively
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.MORE, 20.0, "apex_bloodthirst"))

	var val: float = agg.get_stat("PHYSICAL_DAMAGE", 100.0)
	# Expected: 100 * (1 + 1.0) * 1.35 * 1.20 = 324.0
	T.ok(absf(val - 324.0) < 0.01, "Expected 324.0, got %s" % val)
	return "StatAggregator: Increased additive + More deduplication (324.0)"


static func _test_damage_pipeline_and_no_double_dip() -> String:
	var agg := StatAggregator.new()
	agg.add_modifier(StatTypes.make_mod("PHYSICAL_DAMAGE", StatTypes.ModType.INCREASED, 100.0))
	agg.add_modifier(StatTypes.make_mod("ATTACK_DAMAGE", StatTypes.ModType.MORE, 50.0))
	agg.add_modifier(StatTypes.make_mod("AILMENT_DAMAGE", StatTypes.ModType.INCREASED, 50.0))

	var skill := {
		"damage_source": StatTypes.DamageSource.ATTACK_HIT,
		"tags": ["ATTACK", "MELEE", "PHYSICAL", "BLEED"],
		"base_physical": 100.0,
		"damage_effectiveness": 1.0,
	}
	var defender := {"armour": 300.0, "evasion": 0.0, "fire_res": 0.0}

	var res := DamagePipeline.calculate_hit(agg, defender, skill, true)
	# Raw Phys Hit = 100 * 2.0 (Inc) * 1.5 (More) * 1.5 (Crit) = 450
	T.ok(absf(res["raw_physical"] - 450.0) < 0.01, "Expected raw_physical 450, got %s" % res["raw_physical"])
	# Armour DR = 300 / (300 + 5 * 450) = 300 / 2550 = 0.117647
	# Bleed DPS = 100 * 0.70 * 1.50 (ailment inc only, no hit double-dip) = 105.0
	T.ok(absf(res["bleed_dps"] - 105.0) < 0.01, "Expected bleed_dps 105.0, got %s" % res["bleed_dps"])
	return "DamagePipeline: Hit=450, ArmourDR applied, BleedDPS=105 (no double-dip)"


static func _test_passive_tree_bfs_refund() -> String:
	var tree := PassiveTreeGraph.new()
	var loaded := tree.load_from_json_file("res://data/passive_tree.json")
	T.ok(loaded, "Failed to load res://data/passive_tree.json")

	# Non-adjacent node must be rejected (Lone Wolf only connects to node_ms_01)
	T.ok(not tree.allocate("node_apex_lone_wolf"), "Should reject non-adjacent Lone Wolf")
	T.ok(tree.allocate("node_life_01"), "Should allocate node_life_01")
	T.ok(tree.allocate("node_ms_01"), "Should allocate node_ms_01")
	T.ok(tree.allocate("node_apex_lone_wolf"), "Should allocate Lone Wolf")
	# Cannot refund node_ms_01 because node_apex_lone_wolf depends on it
	T.ok(not tree.can_refund("node_ms_01"), "Should block refunding bridge node")
	# Refund Lone Wolf first, then node_ms_01 becomes refundable
	T.ok(tree.refund("node_apex_lone_wolf"), "Should refund Lone Wolf")
	T.ok(tree.can_refund("node_ms_01"), "Should allow refunding node_ms_01 now")
	return "PassiveTreeGraph: Neighbor allocate + BFS orphan-safe refund"


static func _test_item_generator_seeded_and_currency() -> String:
	var gen := ItemGenerator.new()
	var loaded := gen.load_affixes_from_json_file("res://data/affixes.json")
	T.ok(loaded, "Failed to load res://data/affixes.json")

	var item_a := gen.create_normal_item("base_wolf_boots", "BOOTS", 12, 7777)
	var item_b := gen.create_normal_item("base_wolf_boots", "BOOTS", 12, 7777)
	T.ok(gen.apply_currency(item_a, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE), "Forge failed")
	T.ok(gen.apply_currency(item_b, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE), "Forge failed")
	# Same seed -> identical rolled mods (anti save-scum)
	T.ok(item_a["prefixes"].size() == item_b["prefixes"].size(), "Seeded RNG mismatch")
	T.ok(gen.apply_currency(item_a, StatTypes.CurrencyType.BLOODSTONE_OF_PURGE), "Purge failed")
	T.ok(item_a["rarity"] == StatTypes.Rarity.NORMAL and item_a["prefixes"].is_empty(), "Purge did not clear mods")
	return "ItemGenerator: Seeded anti-save-scum Forge & Purge verified"
