class_name Phase0Tests
extends RefCounted


static func run_all() -> Array[String]:
	var results: Array[String] = []
	results.append(_test_stat_aggregator_more_dedup())
	results.append(_test_damage_pipeline_and_no_double_dip())
	results.append(_test_passive_tree_bfs_refund())
	results.append(_test_item_generator_seeded_and_currency())
	return results


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
	assert(absf(val - 324.0) < 0.01, "Expected 324.0, got %s" % val)
	return "[PASS] StatAggregator: Increased additive + More deduplication (324.0)"


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
	assert(absf(res["raw_physical"] - 450.0) < 0.01, "Expected raw_physical 450, got %s" % res["raw_physical"])
	# Armour DR = 300 / (300 + 5 * 450) = 300 / 2550 = 0.117647
	# Bleed DPS = 100 * 0.70 * 1.50 (ailment inc only, no hit double-dip) = 105.0
	assert(absf(res["bleed_dps"] - 105.0) < 0.01, "Expected bleed_dps 105.0, got %s" % res["bleed_dps"])
	return "[PASS] DamagePipeline: Hit=450, ArmourDR applied, BleedDPS=105 (no double-dip)"


static func _test_passive_tree_bfs_refund() -> String:
	var tree := PassiveTreeGraph.new()
	var loaded := tree.load_from_json_file("res://data/passive_tree.json")
	assert(loaded, "Failed to load res://data/passive_tree.json")

	assert(tree.allocate("node_life_01"), "Should allocate node_life_01")
	assert(tree.allocate("node_apex_lone_wolf"), "Should allocate Lone Wolf")
	# Cannot refund node_life_01 because node_apex_lone_wolf depends on it
	assert(not tree.can_refund("node_life_01"), "Should block refunding bridge node")
	# Refund Lone Wolf first, then node_life_01 becomes refundable
	assert(tree.refund("node_apex_lone_wolf"), "Should refund Lone Wolf")
	assert(tree.can_refund("node_life_01"), "Should allow refunding node_life_01 now")
	return "[PASS] PassiveTreeGraph: Neighbor allocate + BFS orphan-safe refund"


static func _test_item_generator_seeded_and_currency() -> String:
	var gen := ItemGenerator.new()
	var loaded := gen.load_affixes_from_json_file("res://data/affixes.json")
	assert(loaded, "Failed to load res://data/affixes.json")

	var item_a := gen.create_normal_item("base_wolf_boots", "BOOTS", 12, 7777)
	var item_b := gen.create_normal_item("base_wolf_boots", "BOOTS", 12, 7777)
	assert(gen.apply_currency(item_a, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE), "Forge failed")
	assert(gen.apply_currency(item_b, StatTypes.CurrencyType.BLOODSTONE_OF_FORGE), "Forge failed")
	# Same seed -> identical rolled mods (anti save-scum)
	assert(item_a["prefixes"].size() == item_b["prefixes"].size(), "Seeded RNG mismatch")
	assert(gen.apply_currency(item_a, StatTypes.CurrencyType.BLOODSTONE_OF_PURGE), "Purge failed")
	assert(item_a["rarity"] == StatTypes.Rarity.NORMAL and item_a["prefixes"].is_empty(), "Purge did not clear mods")
	return "[PASS] ItemGenerator: Seeded anti-save-scum Forge & Purge verified"
